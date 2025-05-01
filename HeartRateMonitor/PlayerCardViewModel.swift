import Foundation
import SwiftUI
import CoreBluetooth

class PlayerCardViewModel: ObservableObject, Identifiable {
    let id: Int
    let deviceUUID: UUID

    @Published var isConnected: Bool = false
    @Published var hasStartedPlay: Bool = false
    @Published var heartRate: Int = 0
    
    private var lastSentBPM: Int = 0
    private let oscQueue = DispatchQueue(label: "oscQueue", qos: .userInitiated)
    private let bluetoothQueue = DispatchQueue(label: "bluetoothQueue", qos: .userInitiated)

    private let heartRateManager = HeartRateManager()
    private let espManager: ESPPeripheralManager
    private let oscManager = NativeOSCManager()

    // MARK: - Init

    init(id: Int, deviceUUID: UUID, espManager: ESPPeripheralManager) {
        self.id = id
        self.deviceUUID = deviceUUID
        self.espManager = espManager
    }

    // MARK: - Data Sending

    func sendBPMToESP(_ bpm: Int) {
        bluetoothQueue.async { [weak self] in
            self?.espManager.send(bpm: bpm)
        }
    }

    func cycleDidComplete() {
        //Only process if player is actively in play mode
        guard hasStartedPlay, isConnected else { return }
        // Capture value once to ensure consistency
        let bpmToSend = heartRate

        // Skip if no meaningful data to send or no change
        guard bpmToSend > 0 && bpmToSend != lastSentBPM else { return }

        lastSentBPM = bpmToSend
        // Log on main thread to avoid console corruption
         print("🔄 Player \(id) cycle complete - BPM: \(bpmToSend)")

        oscQueue.async { [weak self] in
            guard let self = self else { return }
         //   guard bpmToSend > 0 && bpmToSend < 240 else { return }
            
            // Double-check value range on background thread
//              guard bpmToSend > 0 && bpmToSend < 240 else {
//                  print("⚠️ BPM out of range: \(bpmToSend)")
//                  return
//              }
            //send OSC
            self.oscManager.sendBPM(forPlayer: self.id, bpm: UInt16(bpmToSend))
            }
        // Send to ESP on separate queue to prevent blocking
        self.bluetoothQueue.async {
            self.espManager.send(bpm: bpmToSend)
                  
            print("📡 Thread-safe: Sent BPM \(bpmToSend) to OSC and ESP")
        }
    }

    // MARK: - Bluetooth Lifecycle

    func connect() {
        // Reset state
        hasStartedPlay = false
        isConnected = false
        heartRate = 0
        
        // Set up callbacks
        heartRateManager.onConnect = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = true
                print("✅ Player \(self?.id ?? 0) connected")
            }
        }

        heartRateManager.onHeartRateUpdate = { [weak self] bpm in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Only update if value changed to avoid unnecessary view updates
                if self.heartRate != Int(bpm) {
                    self.heartRate = Int(bpm)
                    print("❤️ Player \(self.id) HR: \(self.heartRate)")
                }
            }
        }

        // Attempt connection
        print("🔗 Connecting Player \(id) to device: \(deviceUUID)")
        heartRateManager.connectToPeripheral(with: deviceUUID)
    }

    func disconnect() {
        heartRateManager.disconnectCurrentPeripheral()
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.hasStartedPlay = false
            self.heartRate = 0
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
