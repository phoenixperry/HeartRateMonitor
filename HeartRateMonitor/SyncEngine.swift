import Foundation

/// The one owner of every oscillator that feeds the V: envelope stream —
/// and of the sync-group logic that decides which players breathe together.
///
/// The model stays deliberately dumb: each player is an independent
/// oscillator (phase += bpm/60 · dt, tempo adopted only at the wrap), exactly
/// like WaveformBreathingCircle and the firmware's local synth. A sync group
/// is just one more oscillator of the same kind, running at the mean BPM of
/// its members. "Phase-locked" means a member's V: slot carries the group
/// oscillator's envelope instead of their own — the firmware never couples
/// anything.
///
/// Transitions are valley-gated so a tempo change never lands mid-pulse:
///   join  — starts at the player's OWN wrap (their envelope is at 0), then
///           crossfades own → group over one group breath, so the motor
///           glides onto the shared pulse instead of jumping to it.
///   leave — happens at the GROUP's wrap: the group envelope is at 0 and the
///           player's own oscillator restarts from phase 0 at their live
///           sensor BPM, so both sides of the handoff are at zero. Seamless
///           by construction.
///
/// Hysteresis is the enter/exit threshold gap plus the valley gating — no
/// extra debounce timers. A slot can change course at most once per breath.
///
/// No timer of its own: GameStateManager's 30 Hz envelope loop calls
/// tick(dt:players:) and streams whatever comes back.
final class SyncEngine: ObservableObject {

    // MARK: - Thresholds (operator-adjustable from the play screen)

    static let defaultEnterThreshold = 3   // join a group when within this many BPM of its tempo
    static let defaultExitThreshold  = 5   // leave once at least this far from it

    @Published private(set) var enterThresholdBPM: Int = SyncEngine.defaultEnterThreshold
    @Published private(set) var exitThresholdBPM: Int  = SyncEngine.defaultExitThreshold

    /// Keep exit strictly above enter — a zero-width band would flap at the
    /// boundary, which is the thing hysteresis exists to prevent.
    func setEnterThreshold(_ value: Int) {
        enterThresholdBPM = max(1, value)
        if exitThresholdBPM <= enterThresholdBPM {
            exitThresholdBPM = enterThresholdBPM + 1
        }
    }

    func setExitThreshold(_ value: Int) {
        exitThresholdBPM = max(enterThresholdBPM + 1, value)
    }

    func resetThresholds() {
        enterThresholdBPM = Self.defaultEnterThreshold
        exitThresholdBPM = Self.defaultExitThreshold
    }

    // MARK: - Model

    struct PlayerSample {
        let id: Int        // 1...6, the V: slot is id − 1
        let bpm: Int       // live sensor BPM
        let active: Bool   // playing, connected, and reporting a real BPM
    }

    private struct Group {
        var bpm: Double    // group tempo — recomputed ONLY at the group's wrap
        var phase: Double  // 0..<1 shared oscillator
    }

    /// Where a player's V: slot gets its envelope from. The associated UUID
    /// names the group; a dictionary key (not an array index) so dissolving
    /// one group can't silently re-point everyone else's state.
    private enum SlotState {
        case solo
        case pendingJoin(UUID)             // qualified — waiting for own valley
        case joining(UUID, t: Double)      // crossfading own → group, t 0..1
        case synced(UUID)                  // group oscillator drives the slot
        case pendingLeave(UUID)            // disqualified — waiting for group valley
    }

    private var groups: [UUID: Group] = [:]
    private var slotState: [Int: SlotState] = [:]
    private var soloPhase: [Int: Double] = [:]
    private var soloBPM: [Int: Int] = [:]

    // MARK: - Lifecycle

    /// Everyone solo. With resetPhasesToZero (resume/restart), every circle
    /// and motor restarts from the most-contracted point at the live sensor
    /// BPM — the phases and tempos re-seed themselves on the next tick.
    func clearGroups(resetPhasesToZero: Bool) {
        groups = [:]
        slotState = [:]
        if resetPhasesToZero {
            soloPhase = [:]
            soloBPM = [:]
        }
    }

    /// True when every active player (and there are at least 2) is a FULL
    /// member of one group. Players still crossfading in don't count — the
    /// strip goes pink exactly when the last motor lands on the shared
    /// breath, not a moment before.
    var allActiveInOneGroup: Bool {
        guard lastActiveIDs.count >= 2 else { return false }
        var lockedGroup: UUID? = nil
        for id in lastActiveIDs {
            switch slotState[id] {
            case .synced(let g), .pendingLeave(let g):
                if lockedGroup == nil { lockedGroup = g }
                else if lockedGroup != g { return false }
            default:
                return false
            }
        }
        return lockedGroup != nil
    }

    private var lastActiveIDs: Set<Int> = []

    // MARK: - The 30 Hz step

    /// Advance every oscillator by dt, churn group membership, and return the
    /// envelope (0...1) for each active player. Inactive players are simply
    /// absent — their V: slot stays 0.
    func tick(dt: TimeInterval, players: [PlayerSample]) -> [Int: Double] {
        let active = players.filter { $0.active }
        let activeIDs = Set(active.map { $0.id })
        let bpmByID = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0.bpm) })
        lastActiveIDs = activeIDs

        // A player that vanishes (strap off, disconnect, BPM 0) detaches
        // immediately — no valley wait, their slot is going to 0 anyway.
        for (id, state) in slotState where !activeIDs.contains(id) {
            if case .solo = state {} else { slotState[id] = .solo }
            soloPhase[id] = nil
            soloBPM[id] = nil
        }

        // -- 1. Advance the oscillators, noting who wrapped this tick. --
        var soloWrapped: Set<Int> = []
        for id in activeIDs {
            // Everyone not fully synced still runs their own oscillator
            // (a joiner needs it until the crossfade completes).
            switch slotState[id] ?? .solo {
            case .synced, .pendingLeave:
                continue
            default:
                break
            }
            var bpm = soloBPM[id] ?? bpmByID[id]!
            var phase = soloPhase[id] ?? 0
            phase += dt * Double(bpm) / 60.0
            if phase >= 1 {
                phase -= phase.rounded(.down)
                bpm = bpmByID[id]!          // tempo shifts only at the wrap
                soloWrapped.insert(id)
            }
            soloBPM[id] = bpm
            soloPhase[id] = phase
        }

        var groupWrapped: Set<UUID> = []
        for (gid, var group) in groups {
            group.phase += dt * group.bpm / 60.0
            if group.phase >= 1 {
                group.phase -= group.phase.rounded(.down)
                groupWrapped.insert(gid)
                // Group tempo = mean of its full members' live BPMs,
                // adopted only here — a tempo change between breaths is an
                // acceleration, never a stutter.
                let memberBPMs = members(of: gid).compactMap { bpmByID[$0] }
                if !memberBPMs.isEmpty {
                    group.bpm = Double(memberBPMs.reduce(0, +)) / Double(memberBPMs.count)
                }
            }
            groups[gid] = group
        }

        // -- 2. Membership churn (threshold checks against live BPMs). --
        for id in activeIDs {
            let bpm = Double(bpmByID[id]!)
            switch slotState[id] ?? .solo {
            case .synced(let gid):
                guard let g = groups[gid] else { slotState[id] = .solo; break }
                if abs(bpm - g.bpm) >= Double(exitThresholdBPM) {
                    slotState[id] = .pendingLeave(gid)
                }
            case .pendingLeave(let gid):
                guard let g = groups[gid] else { slotState[id] = .solo; break }
                if abs(bpm - g.bpm) < Double(exitThresholdBPM) {
                    slotState[id] = .synced(gid)      // drifted back — never left
                }
            case .pendingJoin(let gid):
                guard let g = groups[gid] else { slotState[id] = .solo; break }
                if abs(bpm - g.bpm) > Double(enterThresholdBPM) {
                    slotState[id] = .solo             // bailed before the valley
                }
            case .solo:
                var best: (UUID, Double)? = nil
                for (gid, g) in groups {
                    let dist = abs(bpm - g.bpm)
                    if dist <= Double(enterThresholdBPM), dist < (best?.1 ?? .infinity) {
                        best = (gid, dist)
                    }
                }
                if let (gid, _) = best { slotState[id] = .pendingJoin(gid) }
            case .joining:
                break   // committed — ride the crossfade out
            }
        }

        // Group formation: cluster the remaining solos by BPM. Sorted, a
        // cluster grows while its TOTAL spread stays inside the enter
        // threshold ("within 3 BPM of each other"). Founders enter through
        // the same pendingJoin gate as everyone else — one code path.
        let solos = activeIDs.filter {
            if case .solo = slotState[$0] ?? .solo { return true }
            return false
        }.sorted { bpmByID[$0]! < bpmByID[$1]! }

        var cluster: [Int] = []
        func commitCluster() {
            guard cluster.count >= 2 else { cluster = []; return }
            let mean = Double(cluster.map { bpmByID[$0]! }.reduce(0, +)) / Double(cluster.count)
            let gid = UUID()
            groups[gid] = Group(bpm: mean, phase: 0)
            for id in cluster { slotState[id] = .pendingJoin(gid) }
            cluster = []
        }
        for id in solos {
            if let first = cluster.first,
               Double(bpmByID[id]! - bpmByID[first]!) > Double(enterThresholdBPM) {
                commitCluster()
            }
            cluster.append(id)
        }
        commitCluster()

        // -- 3. Valley-gated transitions. --
        for id in activeIDs {
            switch slotState[id] ?? .solo {
            case .pendingJoin(let gid):
                if soloWrapped.contains(id) {
                    slotState[id] = .joining(gid, t: 0)
                }
            case .joining(let gid, var t):
                guard let g = groups[gid] else { slotState[id] = .solo; break }
                t += dt / (60.0 / g.bpm)            // one group breath
                if t >= 1 {
                    slotState[id] = .synced(gid)
                    soloPhase[id] = nil             // own oscillator retires
                    soloBPM[id] = nil
                } else {
                    slotState[id] = .joining(gid, t: t)
                }
            case .pendingLeave(let gid):
                if groupWrapped.contains(gid) {
                    slotState[id] = .solo
                    soloPhase[id] = 0               // group is at 0; so are we
                    soloBPM[id] = bpmByID[id]!      // back on the live tempo
                }
            default:
                break
            }
        }

        // -- 4. Dissolve groups that no longer hold two people. --
        for gid in groups.keys {
            let attached = activeIDs.filter { attachedGroup(of: $0) == gid }
            if attached.count < 2 {
                for id in attached {
                    // A lone full member peels off cleanly at the group
                    // valley; a lone joiner just falls back to its own
                    // oscillator (still running, still near it).
                    switch slotState[id] ?? .solo {
                    case .synced:
                        slotState[id] = .pendingLeave(gid)
                    case .pendingJoin, .joining:
                        slotState[id] = .solo
                    default:
                        break
                    }
                }
                if attached.isEmpty { groups[gid] = nil }
            }
        }

        // -- 5. Envelopes out. --
        var out: [Int: Double] = [:]
        for id in activeIDs {
            switch slotState[id] ?? .solo {
            case .solo, .pendingJoin:
                out[id] = envelope(soloPhase[id] ?? 0)
            case .joining(let gid, let t):
                let own = envelope(soloPhase[id] ?? 0)
                let grp = groups[gid].map { envelope($0.phase) } ?? own
                out[id] = (1 - t) * own + t * grp
            case .synced(let gid), .pendingLeave(let gid):
                out[id] = groups[gid].map { envelope($0.phase) } ?? envelope(soloPhase[id] ?? 0)
            }
        }
        return out
    }

    // MARK: - Helpers

    /// The same curve as WaveformBreathingCircle and the firmware's raised
    /// cosine: 0 at the wrap (most contracted), 1 mid-breath.
    private func envelope(_ phase: Double) -> Double {
        (sin(2 * Double.pi * phase - .pi / 2) + 1) / 2
    }

    /// Full members only — synced or on their way out, not still joining.
    private func members(of gid: UUID) -> [Int] {
        lastActiveIDs.filter {
            switch slotState[$0] {
            case .synced(let g), .pendingLeave(let g): return g == gid
            default: return false
            }
        }
    }

    /// Whatever group this player is attached to in ANY capacity.
    private func attachedGroup(of id: Int) -> UUID? {
        switch slotState[id] ?? .solo {
        case .pendingJoin(let g), .joining(let g, _), .synced(let g), .pendingLeave(let g):
            return g
        case .solo:
            return nil
        }
    }
}
