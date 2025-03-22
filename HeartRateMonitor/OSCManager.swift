import Foundation
import Network

// MARK: - Heart Rate Manager
class HeartRateManager {
    // BPM with property observer to notify changes
    var currentBPM: UInt16 = 80 {
        didSet {
            if oldValue != currentBPM {
                bpmChangeHandlers.forEach { $0(currentBPM) }
            }
        }
    }
    
    // Multiple handlers can be registered
    private var bpmChangeHandlers: [(UInt16) -> Void] = []
    
    // Register a handler to be called when BPM changes
    func onBPMChange(handler: @escaping (UInt16) -> Void) {
        bpmChangeHandlers.append(handler)
        // Immediately call with current value
        handler(currentBPM)
    }
    
    // Example method that might be called from sensor data
    func updateFromSensor(newBPM: UInt16) {
        currentBPM = newBPM
    }
}

// MARK: - OSC Manager
class NativeOSCManager {
    private var connection: NWConnection?
    private let defaultAddress = "/bpm"
    private var host: NWEndpoint.Host
    private var port: NWEndpoint.Port
    
    init(ipAddress: String = "127.0.0.1", port: Int = 8000, initialBPM: UInt16 = 120) {
        self.host = NWEndpoint.Host(ipAddress)
        self.port = NWEndpoint.Port(integerLiteral: UInt16(port))
        setupConnection()
        
        // Send initial BPM value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendBPM(initialBPM)
        }
    }
    
    deinit {
        connection?.cancel()
    }
    
    private func setupConnection() {
        connection = NWConnection(host: host, port: port, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("OSC connection ready")
            case .failed(let error):
                print("OSC connection failed: \(error)")
                self?.reconnect()
            case .cancelled:
                print("OSC connection cancelled")
            default:
                break
            }
        }
        
        connection?.start(queue: .global())
    }
    
    private func reconnect() {
        connection?.cancel()
        setupConnection()
    }
    
    // MARK: - Public Methods
    
    func updateBPM(_ newBPM: UInt16) {
        sendBPM(newBPM)
    }
    
    func changeDestination(ipAddress: String, port: Int) {
        self.host = NWEndpoint.Host(ipAddress)
        self.port = NWEndpoint.Port(integerLiteral: UInt16(port))
        connection?.cancel()
        setupConnection()
    }
    
    // MARK: - OSC Message Sending
    
    func sendBPM(_ bpm: UInt16) {
        sendOSCMessage(address: defaultAddress, value: bpm)
    }
    
    private func sendOSCMessage(address: String, value: UInt16) {
        guard let connection = connection, connection.state == .ready else {
            print("OSC connection not ready")
            return
        }
        
        let data = createOSCMessage(address: address, value: value)
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send OSC message: \(error)")
            }
        })
    }
    
    private func createOSCMessage(address: String, value: UInt16) -> Data {
        var data = Data()
        
        // 1. OSC Address Pattern
        data.append(address.data(using: .utf8)!)
        // Pad to multiple of 4 bytes
        let addressPadding = 4 - (address.count % 4)
        if addressPadding < 4 {
            data.append(contentsOf: [UInt8](repeating: 0, count: addressPadding))
        }
        
        // 2. OSC Type Tag String
        // Using "i" for integer instead of "f" for float
        let typeTag = ",i"
        data.append(typeTag.data(using: .utf8)!)
        // Pad to multiple of 4 bytes
        let typePadding = 4 - (typeTag.count % 4)
        if typePadding < 4 {
            data.append(contentsOf: [UInt8](repeating: 0, count: typePadding))
        }
        
        // 3. OSC Arguments (integer value)
        // Convert UInt16 to Int32 for OSC protocol (OSC uses 32-bit integers)
        var int32Value = Int32(value).bigEndian
        data.append(Data(bytes: &int32Value, count: MemoryLayout<Int32>.size))
        
        return data
    }
}

// MARK: - App Controller
class AppController {
    private let heartRateManager = HeartRateManager()
    private let oscManager: NativeOSCManager
    
    init() {
        // Initialize OSC with current heart rate
        oscManager = NativeOSCManager(initialBPM: heartRateManager.currentBPM)
        
        // Register for BPM changes
        heartRateManager.onBPMChange { [weak self] newBPM in
            self?.oscManager.updateBPM(newBPM)
        }
    }
    
    // Example method that might be called from UI or sensor
    func updateHeartRate(to bpm: UInt16) {
        heartRateManager.bpm = bpm
    }
}

// Usage example
//let appController = AppController()

// When heart rate changes (e.g., from sensor or UI):
//appController.updateHeartRate(to: 85)

