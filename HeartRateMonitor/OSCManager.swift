import Foundation
import Network

class NativeOSCManager {
    private var connection: NWConnection?
    private var host: NWEndpoint.Host
    private var port: NWEndpoint.Port

    init(ipAddress: String = "127.0.0.1", port: Int = 8000) {
        self.host = NWEndpoint.Host(ipAddress)
        self.port = NWEndpoint.Port(integerLiteral: UInt16(port))
        setupConnection()
    }

    deinit {
        connection?.cancel()
    }
//this is the way swift checks to see if something it not NIL and it's called optional channing
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

    // MARK: - Public API

    func sendBPM(forPlayer id: Int, bpm: UInt16) {
        let address = "/player/\(id)/bpm"
        sendOSCMessage(address: address, value: bpm)
    }
    // specific for wekinator
    func sendGroupBPMs(_ bpmValues: [UInt16]) {
        let address = "/wek/bpm"
        sendOSCMessage(address: address, values: bpmValues)
    }

    //guard means "Only run if this is true. Check this condition, and if it fails, bail out now. AKA if it's bad, get out now! AKA you at 2 with the fire."
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

    private func sendOSCMessage(address: String, values: [UInt16]) {
        guard let connection = connection, connection.state == .ready else {
            print("OSC connection not ready")
            return
        }

        let data = createOSCBundle(address: address, values: values)

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send OSC bundle: \(error)")
            }
        })
    }

    // MARK: - OSC Packing

    private func createOSCMessage(address: String, value: UInt16) -> Data {
        var data = Data()
        data.append(paddedString(address))
        data.append(paddedString(",i"))

        var int32Value = Int32(value).bigEndian
        data.append(Data(bytes: &int32Value, count: MemoryLayout<Int32>.size))

        return data
    }

    private func createOSCBundle(address: String, values: [UInt16]) -> Data {
        var data = Data()
        data.append(paddedString(address))
        data.append(paddedString("," + String(repeating: "i", count: values.count)))

        for value in values {
            var int32Value = Int32(value).bigEndian
            data.append(Data(bytes: &int32Value, count: MemoryLayout<Int32>.size))
        }

        return data
    }

    private func paddedString(_ string: String) -> Data {
        var data = string.data(using: .utf8)!
        let pad = 4 - (data.count % 4)
        if pad < 4 {
            data.append(contentsOf: [UInt8](repeating: 0, count: pad))
        }
        return data
    }
}
