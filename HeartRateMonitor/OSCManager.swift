//
//  NativeOSCManager.swift
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 2025-04-17.
//

import Foundation
import Network

// MARK: - NativeOSCManager

class NativeOSCManager {
    private var connection: NWConnection?
    private let defaultAddress = "/bpm"
    private var host: NWEndpoint.Host
    private var port: NWEndpoint.Port

    init(ipAddress: String = "127.0.0.1", port: Int = 8000, initialBPM: UInt16 = 120) {
        self.host = NWEndpoint.Host(ipAddress)
        self.port = NWEndpoint.Port(integerLiteral: UInt16(port))
        setupConnection()

        // Optional: Send initial BPM for verification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendBPM(initialBPM)
        }
    }

    deinit {
        connection?.cancel()
    }

    var isConnected: Bool {
        connection?.state == .ready
    }

    // MARK: - Connection Setup

    private func setupConnection() {
        connection = NWConnection(host: host, port: port, using: .udp)

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("📡 OSC connection ready")
            case .failed(let error):
                print("❌ OSC connection failed: \(error)")
                self?.reconnect()
            case .cancelled:
                print("⚠️ OSC connection cancelled")
            default:
                break
            }
        }

        connection?.start(queue: DispatchQueue(label: "osc.connection.queue"))
    }

    private func reconnect() {
        connection?.cancel()
        setupConnection()
    }

    // MARK: - Public Methods

    func updateBPM(_ bpm: UInt16) {
        sendBPM(bpm)
    }

    func send(_ value: UInt16, to address: String) {
        sendOSCMessage(address: address, value: value)
    }

    func changeDestination(ipAddress: String, port: Int) {
        self.host = NWEndpoint.Host(ipAddress)
        self.port = NWEndpoint.Port(integerLiteral: UInt16(port))
        connection?.cancel()
        setupConnection()
    }

    // MARK: - Core OSC Message Handling

    func sendBPM(_ bpm: UInt16) {
        sendOSCMessage(address: defaultAddress, value: bpm)
    }

    private func sendOSCMessage(address: String, value: UInt16) {
        guard let connection = connection, connection.state == .ready else {
            print("⚠️ OSC connection not ready")
            return
        }

        let data = createOSCMessage(address: address, value: value)

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Failed to send OSC message: \(error)")
            } else {
                print("📨 Sent OSC to \(address): \(value)")
            }
        })
    }

    private func createOSCMessage(address: String, value: UInt16) -> Data {
        var data = Data()

        // 1. OSC Address Pattern
        data.append(address.data(using: .utf8)!)
        let addressPadding = (4 - (address.count % 4)) % 4
        data.append(contentsOf: [UInt8](repeating: 0, count: addressPadding))

        // 2. OSC Type Tag String
        let typeTag = ",i"
        data.append(typeTag.data(using: .utf8)!)
        let typePadding = (4 - (typeTag.count % 4)) % 4
        data.append(contentsOf: [UInt8](repeating: 0, count: typePadding))

        // 3. OSC Arguments (32-bit integer value)
        var int32Value = Int32(value).bigEndian
        data.append(Data(bytes: &int32Value, count: MemoryLayout<Int32>.size))

        return data
    }
}


// MARK: - App Controller
//class AppController {
//    private let heartRateManager = HeartRateManager()
//    private let oscManager: NativeOSCManager
//    
//    init() {
//        // Initialize OSC with current heart rate
//        //oscManager = NativeOSCManager(initialBPM: heartRateManager.currentBPM)
//        
//        // Register for BPM changes
//        //heartRateManager.onBPMChange { [weak self] newBPM in
//           // self?.oscManager.updateBPM(newBPM)
//        }
//    }
//    
    // Example method that might be called from UI or sensor
    func updateHeartRate(to bpm: UInt16) {
       // heartRateManager.bpm = bpm
    }


// Usage example
//let appController = AppController()

// When heart rate changes (e.g., from sensor or UI):
//appController.updateHeartRate(to: 85)

