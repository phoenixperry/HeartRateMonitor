import Foundation
import CoreBluetooth

class ESPPeripheralManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    private var centralManager: CBCentralManager!
    private var espPeripheral: CBPeripheral?
    private var bpmCharacteristic: CBCharacteristic?

    // UUIDs must match your ESP32 sketch
    private let serviceUUID = CBUUID(string: "180D")
    private let characteristicUUID = CBUUID(string: "2A39")

    @Published var isConnected: Bool = false

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func send(bpm: Int) {
        guard let peripheral = espPeripheral,
              let characteristic = bpmCharacteristic,
              peripheral.state == .connected else {
            print("⚠️ Not connected to ESP32")
            return
        }

        let bpmString = "\(bpm)"
        if let data = bpmString.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
//            print("📡 Sent BPM: \(bpmString)")
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("🔍 Bluetooth ON — starting scan for ESP32...")
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        } else {
            print("❌ Bluetooth not available: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains("HeartHapticsESP") == true {
            print("💡 Found ESP32: \(peripheral.name ?? "Unknown")")
            espPeripheral = peripheral
            espPeripheral?.delegate = self
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to ESP32")
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 Disconnected from ESP32")
        isConnected = false
        bpmCharacteristic = nil
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                bpmCharacteristic = characteristic
                print("🎯 Ready to send BPM to ESP32")
            }
        }
    }
    func sendGroupBPMs(_ bpmValues: [Int]) {
        guard let peripheral = espPeripheral,
              let characteristic = bpmCharacteristic,
              peripheral.state == .connected else {
            print("⚠️ ESP32 not connected")
            return
        }

        let bpmString = bpmValues.map { String($0) }.joined(separator: ",")
        if let data = bpmString.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
//            print("📡 Sent group BPMs: \(bpmString)")
        }
    }
    func disconnectCurrentPeripheral() {
        if let peripheral = espPeripheral, peripheral.state == .connected {
            centralManager.cancelPeripheralConnection(peripheral)
            print("🔌 Manually disconnected ESP32")
        }
    }
}
