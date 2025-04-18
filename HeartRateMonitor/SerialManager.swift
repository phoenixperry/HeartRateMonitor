import Foundation
import ORSSerial

class SerialManager: NSObject, ORSSerialPortDelegate, ObservableObject  {
    
    @Published var availablePorts: [ORSSerialPort] = []
    @Published var isConnected: Bool = false
    
    private var serialPort: ORSSerialPort?
    private let serialPortManager = ORSSerialPortManager.shared()
    private var targetPortName: String? = nil
    private var reconnectTimer: DispatchSourceTimer?
    
    override init() {
        super.init()
        availablePorts = serialPortManager.availablePorts
    }
    
    func refreshPorts() {
        availablePorts = serialPortManager.availablePorts
        print("🔌 Ports found: \(availablePorts.map { $0.name })")
    }
    
    func connect(to port: ORSSerialPort) {
        disconnect()
        serialPort = port
        serialPort?.baudRate = 9600
        serialPort?.delegate = self
        serialPort?.open()
        if serialPort?.isOpen ?? false {
            DispatchQueue.main.async {
                self.isConnected = true
            }
            targetPortName = port.name
        }
        stopAutoReconnect()
    }

    func disconnect() {
        if let port = serialPort {
            port.close()
            port.delegate = nil
            serialPort = nil
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }
    //note to self // The _ avoids assigning it to an internal var name
    func send(_ message: String) {
        guard let port = serialPort, port.isOpen else {
            print("⚠️ Port not open")
            return
        }

        if let data = (message + "\n").data(using: .utf8) {
            port.send(data)
            print("📨 Sent: \(message)")
        }
    }

    // MARK: - ORSSerialPortDelegate

    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
        print("✅ Connected to \(serialPort.name)")
    }

    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        print("😵 Disconnected from \(serialPort.name)")
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        if let str = String(data: data, encoding: .utf8) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            print("💌 Received: \(trimmed)")
        }
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: any Error) {
        print("😭 Serial error: \(error)")
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print("⚠️ Serial port removed: \(serialPort.name)")
        
        if serialPort == self.serialPort {
            self.serialPort = nil
            DispatchQueue.main.async {
                self.isConnected = false
            }
            startAutoReconnect()
        }
        availablePorts = serialPortManager.availablePorts
    }

    private func startAutoReconnect() {
        stopAutoReconnect()
        reconnectTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        reconnectTimer?.schedule(deadline: .now(), repeating: 2.0)
        reconnectTimer?.setEventHandler { [weak self] in
            self?.checkForReconnection()
        }
        reconnectTimer?.resume()
    }

    private func stopAutoReconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    private func checkForReconnection() {
        guard !isConnected, let targetName = targetPortName else { return }
        refreshPorts()
        
        //note to self $0 is basically like doing a for each in c# where foreach(item in items) is just where($0..)
        if let port = availablePorts.first(where: { $0.name == targetName }) {
            print("🔁 Reconnecting to \(targetName)...")
            connect(to: port)
        }
    }
}
