//
//  AUEngine.swift
//  HeartRateMonitor
//
//  Self-contained Audio Unit host for Arturia's MiniFreak V plugin.
//  Driven by heartbeat events from PlayerCardViewModel so player BPM →
//  pentatonic MIDI notes → MiniFreak V → speakers (and the hardware,
//  when paired over USB).
//
//  ────────────────────────────────────────────────────────────────────
//  To remove this integration entirely (e.g. you switched back to Ableton):
//    1. Delete this file
//    2. Delete the single `AUEngine.shared.noteOnIfEnabled(...)` line
//       inside `PlayerCardViewModel.cycleDidComplete`
//  Nothing else in the app references it.
//  ────────────────────────────────────────────────────────────────────
//
//  Sandbox note:
//  HeartRateMonitor.entitlements currently has app-sandbox = true. Loading
//  a third-party AUv2 plugin (MiniFreak V) from a sandboxed app will fail
//  silently. To make this work you need to either:
//    • flip `com.apple.security.app-sandbox` to <false/> while you experiment,
//      OR
//    • add `com.apple.security.temporary-exception.audio-unit-host` and
//      bundle Arturia inside an exempt path (rarely worth it).
//  AUv3 plugins load out-of-process and work in sandbox, but MiniFreak V is AUv2.

import Foundation
import AVFoundation
import AudioToolbox

final class AUEngine {

    // MARK: - Singleton

    static let shared = AUEngine()

    // MARK: - Configuration

    /// Master kill switch. Defaults to off; flip this in code or via
    /// `UserDefaults.standard.set(true, forKey: "EnableMiniFreakEngine")`.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "EnableMiniFreakEngine")
    }

    /// Per-player MIDI note. Same pentatonic voicing as the web OSC monitor.
    /// Player 1 = C2 (low bass) … Player 6 = C5 (top).
    private let notesByPlayer: [Int: UInt8] = [
        1: 36, // C2
        2: 43, // G2
        3: 50, // D3
        4: 57, // A3
        5: 64, // E4
        6: 72, // C5
    ]

    /// How long the engine holds a note before sending note-off.
    private let noteDuration: TimeInterval = 0.6
    private let velocity: UInt8 = 96
    private let midiChannel: UInt8 = 0

    /// MiniFreak V component description (Arturia AUv2 music device).
    /// Codes verified via the plugin's own Info.plist:
    ///   manufacturer = 'Artu', subtype = 'MnFV', type = 'aumu'.
    private let componentDescription: AudioComponentDescription = {
        var d = AudioComponentDescription()
        d.componentType         = kAudioUnitType_MusicDevice
        d.componentSubType      = OSType(fourCharCode: "MnFV")
        d.componentManufacturer = OSType(fourCharCode: "Artu")
        d.componentFlags        = 0
        d.componentFlagsMask    = 0
        return d
    }()

    // MARK: - State

    private let engine = AVAudioEngine()
    private var instrument: AVAudioUnitMIDIInstrument?
    private var hasStarted = false
    private var startFailed = false
    private let stateQueue = DispatchQueue(label: "auengine.state", qos: .userInitiated)

    /// Tracks the last note we sent per player so we can release it cleanly.
    private var activeNotes: [Int: UInt8] = [:]

    // MARK: - Public API
    // Single entry point used by PlayerCardViewModel. Bootstraps the engine on
    // first call if enabled, then sends a per-heartbeat MIDI note.

    func noteOnIfEnabled(player: Int) {
        guard isEnabled, !startFailed else { return }
        if !hasStarted {
            startEngine()
            guard !startFailed else { return }
        }
        sendNoteOn(player: player)
    }

    /// Call from GameStateManager.endGame / resetGame if you want notes to
    /// stop the instant the round ends, rather than fading out naturally.
    func allNotesOff() {
        guard let mi = instrument else { return }
        for (_, note) in activeNotes {
            mi.sendMIDIEvent(0x80 | midiChannel, data1: note, data2: 0)
        }
        activeNotes.removeAll()
    }

    // MARK: - Lifecycle

    private func startEngine() {
        guard !hasStarted else { return }
        // Find the MiniFreak component.
        var desc = componentDescription
        guard AudioComponentFindNext(nil, &desc) != nil else {
            print("🎹 AUEngine: MiniFreak V not found at type=aumu subtype=MFre manufacturer=Arta. Is the AU installed at /Library/Audio/Plug-Ins/Components ?")
            startFailed = true
            return
        }

        AVAudioUnit.instantiate(with: desc, options: []) { [weak self] avUnit, error in
            guard let self else { return }
            if let error {
                print("🎹 AUEngine: AVAudioUnit.instantiate failed — \(error.localizedDescription)")
                self.startFailed = true
                return
            }
            guard let mi = avUnit as? AVAudioUnitMIDIInstrument else {
                print("🎹 AUEngine: instantiated unit is not an MIDI instrument, type=\(type(of: avUnit))")
                self.startFailed = true
                return
            }

            self.engine.attach(mi)
            self.engine.connect(mi, to: self.engine.mainMixerNode, format: nil)
            self.engine.prepare()
            do {
                try self.engine.start()
                self.instrument = mi
                self.hasStarted = true
                print("🎹 AUEngine: MiniFreak V loaded and engine started.")
            } catch {
                print("🎹 AUEngine: engine.start() failed — \(error.localizedDescription)")
                self.startFailed = true
            }
        }
    }

    // MARK: - MIDI dispatch

    private func sendNoteOn(player: Int) {
        guard let mi = instrument,
              let note = notesByPlayer[player] else { return }

        // Release any still-held note from this player to avoid stuck notes.
        if let previous = activeNotes[player] {
            mi.sendMIDIEvent(0x80 | midiChannel, data1: previous, data2: 0)
        }

        mi.sendMIDIEvent(0x90 | midiChannel, data1: note, data2: velocity)
        activeNotes[player] = note
        print("🎹 noteOn  P\(player) note=\(note) vel=\(velocity)")

        // Schedule the matching note-off. We tag the dispatch with the note
        // value so a later beat that overwrote activeNotes[player] doesn't
        // get its note cut short by the old timer.
        let scheduled = note
        DispatchQueue.main.asyncAfter(deadline: .now() + noteDuration) { [weak self] in
            guard let self,
                  let mi = self.instrument,
                  self.activeNotes[player] == scheduled else { return }
            mi.sendMIDIEvent(0x80 | self.midiChannel, data1: scheduled, data2: 0)
            self.activeNotes.removeValue(forKey: player)
        }
    }
}

// MARK: - Helpers

private extension OSType {
    /// Build a four-character code (`OSType`) from a 4-char ASCII string.
    /// Plugin component identifiers are always packed this way.
    init(fourCharCode s: StaticString) {
        precondition(s.utf8CodeUnitCount == 4, "fourCharCode must be exactly 4 characters")
        let bytes = s.withUTF8Buffer { Array($0) }
        self = (OSType(bytes[0]) << 24)
             | (OSType(bytes[1]) << 16)
             | (OSType(bytes[2]) << 8)
             |  OSType(bytes[3])
    }
}
