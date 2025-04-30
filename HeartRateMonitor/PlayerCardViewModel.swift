import Foundation
import SwiftUI
import CoreBluetooth

class PlayerCardViewModel: ObservableObject, Identifiable {
    let id: Int
    let deviceUUID: UUID

    @Published var isConnected: Bool = false
    @Published var hasStartedPlay: Bool = false
    @Published var heartRate: Int = 0
    @State var shouldAnimate = false
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
        guard hasStartedPlay else { return }

        let bpmToSend = heartRate

        // Only send if BPM changed
        guard bpmToSend != lastSentBPM else { return }

        lastSentBPM = bpmToSend

        oscQueue.async { [weak self] in
            guard let self = self else { return }
            guard bpmToSend > 0 && bpmToSend < 240 else { return }

            self.oscManager.sendBPM(forPlayer: self.id, bpm: UInt16(bpmToSend))
            self.sendBPMToESP(bpmToSend) // Optional: send to ESP too
            print("📡 Thread-safe: Sent BPM \(bpmToSend) to OSC and ESP")
        }
    }

//    func sendOSC(bpm: Int) {
//        guard hasStartedPlay else { return }
//        guard bpm > 0 && bpm < 240 else { return }
//
//        oscManager.sendBPM(forPlayer: id, bpm: UInt16(bpm))
//        print("📡 Sent OSC BPM: \(bpm) to /player/\(id)/bpm")
//    }

    // MARK: - Bluetooth Lifecycle

    func connect() {
        hasStartedPlay = false
        isConnected = false
        heartRate = 0
        shouldAnimate = true

        heartRateManager.onConnect = { [weak self] in
            self?.isConnected = true
        }

        heartRateManager.onHeartRateUpdate = { [weak self] bpm in
            guard let self = self else { return }
            self.heartRate = Int(bpm)
//            if self.hasStartedPlay {
//                self.sendOSC(bpm: Int(bpm))
//            }
        }

        heartRateManager.connectToPeripheral(with: deviceUUID)
    }

    func disconnect() {
        heartRateManager.disconnectCurrentPeripheral()
        isConnected = false
        hasStartedPlay = false
        shouldAnimate = false
    }

    func startPlay() {
        hasStartedPlay = true
    }
}

