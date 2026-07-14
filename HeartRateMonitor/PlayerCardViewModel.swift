import Foundation
import SwiftUI
import CoreBluetooth

class PlayerCardViewModel: ObservableObject, Identifiable {
    let id: Int
    let deviceUUID: UUID
    let isSimulated: Bool

    // The physical hardware tile (motor + light channel, 1-6) this player
    // drives. Defaults to the player's own id so, absent any tile config, a
    // player still lands on the channel they always did. GameStateManager
    // sets this from the tile assignment when it (re)builds the players.
    var tileChannel: Int

    @Published var isConnected: Bool = false
    @Published var hasStartedPlay: Bool = false
    @Published var heartRate: Int = 0
    @Published var currentScale:CGFloat = 1.0

    private var lastSentBPM: Int = 0
    private var lastCycleAt: Date? = nil   // dedup: one beat per breathing cycle
    var isGamePaused: Bool = false         // set by GameStateManager on pause/resume:
                                           // gates ALL per-beat output (K:, OSC, MIDI)
    var outputEnabled: Bool = false        // whether this player's per-beat output (tile
                                           // haptic + tempo + their note) may reach the
                                           // hardware. Turned ON the moment they tap
                                           // "You're in" (startPlay) — so each player gets
                                           // to meet the sound + tile pulse they make while
                                           // still on the setup screen, before the group
                                           // experience begins — and stays on through play.
                                           // Turned OFF on pause/end/reset so a joined
                                           // player can't wake the firmware (S:/K: flip it
                                           // out of DONE) after the experience is over.
                                           // The startup "flash" fix lives elsewhere now:
                                           // GameStateManager fades the V: envelope in.
    private let oscQueue = DispatchQueue(label: "oscQueue", qos: .userInitiated)
    private let bluetoothQueue = DispatchQueue(label: "bluetoothQueue", qos: .userInitiated)

    private var heartRateManager: HeartRateManager?
    private let espManager: ESPPeripheralManager
    private let oscManager = NativeOSCManager()

    // MARK: - Init

    init(id: Int, deviceUUID: UUID, espManager: ESPPeripheralManager, simulated: Bool = false) {
        self.id = id
        self.deviceUUID = deviceUUID
        self.tileChannel = id      // identity until GameStateManager applies the tile map
        self.espManager = espManager
        self.isSimulated = simulated
        self.heartRateManager = simulated ? nil : HeartRateManager()
    }

    // MARK: - Data Sending

    func sendBPMToESP(_ playerID: Int, bpm: Int) {
        bluetoothQueue.async { [weak self] in
            self?.espManager.sendTempo(id:playerID,bpm:bpm)
        }
    }
    
    func sendHapticsToESP(_ playerID: Int) {
        bluetoothQueue.async { [weak self] in
            self?.espManager.sendHaptics(id:playerID)
        }
    }

    func cycleDidComplete() {
        //Only fire once the player has joined ("You're in") and output is
        //enabled — enabled in the setup lobby AND during play, disabled on
        //pause/end/reset. This lets each player feel their tile + hear their
        //note on the setup screen, while never leaking a beat after the round.
        guard hasStartedPlay, isConnected, !isGamePaused, outputEnabled else { return }
        // One beat per breathing cycle, whichever clock fires first. TWO paths
        // call this for simulated players — the circle view's onCycleComplete
        // AND updateSimulatedBPM (which fires on every sim tick / BPM change).
        // Unguarded, the second clock doubled every K:, OSC beat, and note.
        let period = 60.0 / Double(max(heartRate, 1))
        let nowT = Date()
        if let last = lastCycleAt, nowT.timeIntervalSince(last) < period * 0.6 { return }
        lastCycleAt = nowT
        // Capture value once to ensure consistency
        let bpmToSend = heartRate
        sendHapticsToESP(tileChannel)   // fire the motor on this player's tile

        // Per-heartbeat OSC pulse, fires every cycle regardless of BPM change.
        // Separate channel from /player/N/bpm — consumers can pick whichever fits.
        let beatBPM = max(0, bpmToSend)
        oscQueue.async { [weak self] in
            guard let self = self else { return }
            //self.oscManager.sendBeat(forPlayer: self.id, bpm: UInt16(beatBPM))
        }

        // ──────────────────────────────────────────────────────────────────
        // OPTIONAL: drive the Arturia MiniFreak V audio unit on each heartbeat.
        //
        // What this does:
        //   AUEngine hosts the MiniFreak V plugin in-process. This call fires
        //   the player's locked pentatonic MIDI note (P1=C2 … P6=C5). If the
        //   AU is paired with the hardware over USB, the hardware plays it too.
        //
        // It's gated by `UserDefaults.standard.bool(forKey: "EnableMiniFreakEngine")`.
        // When that key is false (the default), this line is a near-zero-cost
        // no-op — the engine never even loads.
        //
        // To turn it on (one-time, persists across launches):
        //     UserDefaults.standard.set(true, forKey: "EnableMiniFreakEngine")
        //   …or expose a Toggle in ConfigurationScreen bound to that key.
        //
        // To remove the integration entirely (go back to pure-Ableton routing):
        //   1. Delete this single line below.
        //   2. Delete AUEngine.swift.
        // Nothing else in the app references the engine.
        // ──────────────────────────────────────────────────────────────────
        AUEngine.shared.noteOnIfEnabled(player: id)

        // Skip if no meaningful data to send or no change
        guard bpmToSend > 0 && bpmToSend != lastSentBPM else { return }
        //make sure that the bpm actually needs updating
    
        lastSentBPM = bpmToSend
        // Log on main thread to avoid console corruption
         print("🔄 Player \(id) cycle complete - BPM: \(bpmToSend)")
    
        //send osc on background tnot hread
        oscQueue.async { [weak self] in
            guard let self = self else { return }
         //   guard bpmToSend > 0 && bpmToSend < 240 else { return }
            
            // Double-check value range on background thread - there might be some cause for filtering for wild values from the sensors.
              guard bpmToSend > 0 && bpmToSend < 240 else {
                  print("⚠️ BPM out of range: \(bpmToSend)")
                  return
              }
            //send OSC
            //self.oscManager.sendBPM(forPlayer: self.id, bpm: UInt16(bpmToSend))
        
            }
    
        // Send to ESP on separate queue to prevent blocking
        bluetoothQueue.async {[weak self] in
            guard let self = self else { return }
     
            self.espManager.sendTempo(id: self.tileChannel, bpm: bpmToSend)
            //print("📡 Player(\(self.id)): Sent BPM \(bpmToSend) to OSC and ESP")
        }
    }

    // MARK: - Simulation

    func updateSimulatedBPM(_ bpm: Int) {
        guard isSimulated else { return }
        DispatchQueue.main.async {
            if self.heartRate != bpm {
                self.heartRate = bpm
            }
            self.cycleDidComplete()
        }
    }

    // MARK: - Bluetooth Lifecycle

    func connect() {
        guard !isSimulated else { return }

        // Reset state
        hasStartedPlay = false
        isConnected = false
        heartRate = 0

        // Set up callbacks
        heartRateManager?.onConnect = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = true
                print("✅ Player \(self?.id ?? 0) connected")
            }
        }

        // Physical strap death (BLE drop) — same handling as the Disconnect
        // button: clear state and stop this player's motor immediately.
        heartRateManager?.onDisconnect = { [weak self] in
            self?.disconnect()
        }

        heartRateManager?.onHeartRateUpdate = { [weak self] bpm in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let wasZero = self.heartRate == 0
                let isNonZero = bpm > 0

                if self.heartRate != Int(bpm) {
                    self.heartRate = Int(bpm)
                }

                // Fire an immediate note the first time BPM actually arrives
                // for a player who's already joined the group, so they don't
                // wait a full breathing-circle cycle (~1 s at resting BPM, but
                // up to a minute if currentBPM was still at the bootstrap
                // value) before they hear anything. Subsequent beats come from
                // the cycle-completed callback as normal.
                if wasZero && isNonZero && self.hasStartedPlay && self.isConnected && self.outputEnabled {
                    AUEngine.shared.noteOnIfEnabled(player: self.id)
                }

                // Disconnect if heart rate drops to 0 during gameplay
                if bpm == 0 && self.hasStartedPlay {
                    print("💔 Player \(self.id) heart rate dropped to 0 - disconnecting")
                    self.disconnect()
                }
            }
        }

        // Attempt connection
        print("🔗 Connecting Player \(id) to device: \(deviceUUID)")
        heartRateManager?.connectToPeripheral(with: deviceUUID)
    }

    func disconnect() {
        guard !isSimulated else { return }

        // Stop this player's motor NOW — S:<channel>:0 is the firmware stop
        // command (monitor and motor are twins). Sent to the player's tile so
        // the right tile falls silent even if UI state teardown lags.
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            self.espManager.sendTempo(id: self.tileChannel, bpm: 0)
        }

        heartRateManager?.disconnectCurrentPeripheral()

        DispatchQueue.main.async {
            self.isConnected = false
            self.hasStartedPlay = false
            self.heartRate = 0
            self.lastSentBPM = 0
            print("🔌 Player \(self.id) disconnected")
        }
    }

    /// Join the group. `announce` gives an immediate one-shot tile pulse + note
    /// the instant the player taps "You're in" on the setup screen, so joining
    /// is felt and heard right away instead of on their next heartbeat. The bulk
    /// start from startGame() leaves it false — an extra kick there would blip
    /// the motors just as the smooth envelope fade-in begins.
    func startPlay(announce: Bool = false) {
        DispatchQueue.main.async {
            self.hasStartedPlay = true
            self.outputEnabled = true      // enable this player's tile + sound now
            if announce && self.isConnected {
                self.sendHapticsToESP(self.tileChannel)          // buzz their tile once
                AUEngine.shared.noteOnIfEnabled(player: self.id) // sound their note once
            }
            print("▶️ Player \(self.id) started play")
        }
    }
}
