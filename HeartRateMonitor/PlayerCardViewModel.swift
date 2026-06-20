import Foundation
import SwiftUI
import CoreBluetooth

class PlayerCardViewModel: ObservableObject, Identifiable {
    let id: Int
    let deviceUUID: UUID
    let isSimulated: Bool

    @Published var isConnected: Bool = false
    @Published var hasStartedPlay: Bool = false
    @Published var heartRate: Int = 0
    @Published var currentScale:CGFloat = 1.0

    private var lastSentBPM: Int = 0
    private let oscQueue = DispatchQueue(label: "oscQueue", qos: .userInitiated)
    private let bluetoothQueue = DispatchQueue(label: "bluetoothQueue", qos: .userInitiated)

    private var heartRateManager: HeartRateManager?
    private let espManager: ESPPeripheralManager
    private let oscManager = NativeOSCManager()

    // MARK: - Init

    init(id: Int, deviceUUID: UUID, espManager: ESPPeripheralManager, simulated: Bool = false) {
        self.id = id
        self.deviceUUID = deviceUUID
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
        //Only process if player is actively in play mode
        guard hasStartedPlay, isConnected else { return }
        // Capture value once to ensure consistency
        let bpmToSend = heartRate
        sendHapticsToESP(id)

        // Per-heartbeat OSC pulse, fires every cycle regardless of BPM change.
        // Separate channel from /player/N/bpm — consumers can pick whichever fits.
        let beatBPM = max(0, bpmToSend)
        oscQueue.async { [weak self] in
            guard let self = self else { return }
            self.oscManager.sendBeat(forPlayer: self.id, bpm: UInt16(beatBPM))
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
//              guard bpmToSend > 0 && bpmToSend < 240 else {
//                  print("⚠️ BPM out of range: \(bpmToSend)")
//                  return
//              }
            //send OSC
            self.oscManager.sendBPM(forPlayer: self.id, bpm: UInt16(bpmToSend))
        
            }
    
        // Send to ESP on separate queue to prevent blocking
        bluetoothQueue.async {[weak self] in
            guard let self = self else { return }
     
            self.espManager.sendTempo(id: self.id, bpm: bpmToSend)
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
                if wasZero && isNonZero && self.hasStartedPlay && self.isConnected {
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

        heartRateManager?.disconnectCurrentPeripheral()

        DispatchQueue.main.async {
            self.isConnected = false
            self.hasStartedPlay = false
            self.heartRate = 0
            self.lastSentBPM = 0
            print("🔌 Player \(self.id) disconnected")
        }
    }

    func startPlay() {
        DispatchQueue.main.async {
            self.hasStartedPlay = true
            print("▶️ Player \(self.id) started play")
            
        }
    }
}
