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
import AppKit
import CoreAudioKit   // exposes AUAudioUnit.requestViewController(completionHandler:)
import CoreMIDI       // hardware → plugin MIDI bridge

final class AUEngine {

    // MARK: - Singleton

    static let shared = AUEngine()

    // MARK: - Configuration

    /// Master kill switch. Defaults to off; flip this in code or via
    /// `UserDefaults.standard.set(true, forKey: "EnableMiniFreakEngine")`.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "EnableMiniFreakEngine")
    }

    // Per-player MIDI note, velocity and note duration all come from the
    // active SoundPreset via SoundDesignManager. Lets the Sound Designer
    // screen swap voicings live (different scales, different per-player
    // assignments) while the operator auditions sounds with the MiniFreak
    // plugin open.
    private var notesByPlayer: [Int: UInt8] {
        SoundDesignManager.shared.active.notesByPlayer
    }
    private var noteDuration: TimeInterval {
        SoundDesignManager.shared.active.noteDuration
    }
    private var velocity: UInt8 {
        SoundDesignManager.shared.active.velocity
    }
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

    /// Strong reference to the plugin's UI window so it isn't deallocated
    /// the moment the helper returns.
    private var pluginWindow: NSWindow?

    // MARK: - Hardware MIDI bridge state
    // Ableton routes hardware MIDI into the plugin for us; in a custom AU host
    // we have to do it ourselves. These are the CoreMIDI handles for that.
    private var midiClient: MIDIClientRef = 0
    private var midiInputPort: MIDIPortRef = 0
    private var bridgedSources: [MIDIEndpointRef] = []
    private let hardwareNameMatch = "MiniFreak"

    /// True if the engine is loaded and ready for `openPluginUI()` to work.
    var isReady: Bool { hasStarted && instrument != nil }

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

    /// Master mute for game pause: output volume to 0 and silence anything
    /// already ringing. Safe to call whether or not the engine ever started
    /// (a never-started engine's mixer just holds the value for later).
    func setMuted(_ muted: Bool) {
        engine.mainMixerNode.outputVolume = muted ? 0 : 1
        if muted && hasStarted { allNotesOff() }
    }

    /// Fire an arbitrary MIDI note now, ignoring the per-player map.
    /// Used by the Sound Designer screen so each player row's "test"
    /// button can audition exactly what that player will play.
    /// Bootstraps the engine if needed.
    func playTestNote(midi: UInt8) {
        guard isEnabled, !startFailed else { return }
        if !hasStarted {
            startEngine()
            guard !startFailed else { return }
        }
        guard let mi = instrument else { return }
        let dur = noteDuration
        let vel = velocity
        let ch = midiChannel
        mi.sendMIDIEvent(0x90 | ch, data1: midi, data2: vel)
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) { [weak self] in
            guard let self = self, let mi = self.instrument else { return }
            mi.sendMIDIEvent(0x80 | ch, data1: midi, data2: 0)
        }
    }

    /// Open the MiniFreak V plugin's native UI in a floating window. From there
    /// you can load/save presets, set the voice mode to polyphonic, configure
    /// MIDI input from the hardware (to bond it), edit sound design, etc.
    /// Safe to call before the engine has started — it'll bootstrap if needed.
    /// Idempotent: a second call just brings the existing window forward.
    func openPluginUI() {
        if let existing = pluginWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if !hasStarted { startEngine() }
        guard let instrument else {
            print("🎹 openPluginUI: engine isn't loaded yet — nothing to show")
            return
        }

        instrument.auAudioUnit.requestViewController { [weak self] viewController in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let vc = viewController else {
                    print("🎹 openPluginUI: plugin returned no view controller")
                    return
                }
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
                    styleMask: [.titled, .closable, .resizable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "MiniFreak V"
                window.contentViewController = vc
                window.center()
                window.isReleasedWhenClosed = false
                window.delegate = AUEnginePluginWindowDelegate.shared
                self.pluginWindow = window
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }


    /// Tear down the audio engine and detach the plugin cleanly. Call from
    /// AppDelegate.applicationWillTerminate so the plugin's audio IO thread
    /// doesn't keep reading freed memory after the app dies — that's what
    /// produces the EXC_BAD_ACCESS in MiniFreak V on quit.
    func shutdown() {
        guard hasStarted else { return }
        tearDownMIDIHardwareBridge()
        allNotesOff()
        if let instrument {
            // Stop notifications + render before detach so the IO thread doesn't
            // tick on a half-freed graph.
            engine.disconnectNodeInput(instrument)
            engine.detach(instrument)
        }
        engine.stop()
        if let win = pluginWindow {
            win.delegate = nil
            win.close()
            pluginWindow = nil
        }
        instrument = nil
        hasStarted = false
        print("🎹 AUEngine: shut down cleanly.")
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
                self.setupMIDIHardwareBridge()
            } catch {
                print("🎹 AUEngine: engine.start() failed — \(error.localizedDescription)")
                self.startFailed = true
            }
        }
    }

    // MARK: - Hardware MIDI bridge
    // Forwards every MIDI event from a connected MiniFreak hardware into the
    // plugin, just like Ableton would. One-direction (hardware → plugin) only;
    // plugin → hardware sync isn't possible from plugin mode anyway.

    private func setupMIDIHardwareBridge() {
        guard midiClient == 0 else { return }

        var status = MIDIClientCreateWithBlock("HRM-AUHost" as CFString, &midiClient) { _ in /* device-change notifications, unused */ }
        guard status == noErr else {
            print("🎹 MIDI bridge: MIDIClientCreate failed (\(status))"); return
        }

        status = MIDIInputPortCreateWithBlock(midiClient, "HRM-In" as CFString, &midiInputPort) { [weak self] listPtr, _ in
            self?.routeMIDIPackets(listPtr)
        }
        guard status == noErr else {
            print("🎹 MIDI bridge: MIDIInputPortCreate failed (\(status))"); return
        }

        connectAllMatchingSources()
    }

    private func connectAllMatchingSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let source = MIDIGetSource(i)
            guard source != 0 else { continue }

            var nameProp: Unmanaged<CFString>?
            let s = MIDIObjectGetStringProperty(source, kMIDIPropertyName, &nameProp)
            guard s == noErr, let cfName = nameProp?.takeRetainedValue() as String? else { continue }

            if cfName.localizedCaseInsensitiveContains(hardwareNameMatch) {
                let cs = MIDIPortConnectSource(midiInputPort, source, nil)
                if cs == noErr {
                    bridgedSources.append(source)
                    print("🎹 MIDI bridge: connected to \(cfName)")
                } else {
                    print("🎹 MIDI bridge: failed to connect \(cfName) (\(cs))")
                }
            }
        }
        if bridgedSources.isEmpty {
            print("🎹 MIDI bridge: no MiniFreak device found in CoreMIDI sources")
        }
    }

    private func routeMIDIPackets(_ listPtr: UnsafePointer<MIDIPacketList>) {
        guard let mi = instrument else { return }

        let list = listPtr.pointee
        var packet = list.packet
        for _ in 0..<list.numPackets {
            forwardPacket(packet, to: mi)
            packet = withUnsafePointer(to: &packet) { MIDIPacketNext($0).pointee }
        }
    }

    private func forwardPacket(_ packet: MIDIPacket, to mi: AVAudioUnitMIDIInstrument) {
        let length = Int(packet.length)
        guard length > 0 else { return }
        guard let scheduleMIDI = mi.auAudioUnit.scheduleMIDIEventBlock else {
            print("🎹 MIDI bridge: AU has no scheduleMIDIEventBlock — can't forward")
            return
        }

        // Extract the bytes out of the fixed-size tuple `data` (256 bytes per
        // MIDIPacket) and hand the whole packet straight into the AU's MIDI
        // ingress. This is the general path that accepts channel voice
        // messages, SysEx, system realtime — everything.
        var data = packet.data
        withUnsafeBytes(of: &data) { rawBuf in
            guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            scheduleMIDI(AUEventSampleTimeImmediate, 0, length, base)
        }
    }

    private func tearDownMIDIHardwareBridge() {
        for source in bridgedSources {
            MIDIPortDisconnectSource(midiInputPort, source)
        }
        bridgedSources.removeAll()
        if midiInputPort != 0 { MIDIPortDispose(midiInputPort); midiInputPort = 0 }
        if midiClient != 0    { MIDIClientDispose(midiClient);    midiClient    = 0 }
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

// MARK: - Plugin window delegate

/// Intercepts the user clicking the window's close button and hides the
/// window instead of letting AppKit close it. Why: asking the AU for a
/// fresh view controller on a second open fails (MiniFreak's gear/settings
/// path), so we keep the same window+VC for the life of the app and just
/// orderOut/orderFront it. The window object stays alive for the next
/// openPluginUI() to bring back forward.
private final class AUEnginePluginWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = AUEnginePluginWindowDelegate()
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
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
