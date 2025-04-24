import Foundation
import CoreBluetooth
import Combine

class HeartRateManager: NSObject, ObservableObject {
    // MARK: - Published properties for SwiftUI
    @Published var heartRate: UInt16 = 0
    @Published var connected: String = ""
    @Published var bodyLocation: String = ""
    @Published var manufacturer: String = ""
    @Published var isConnected: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var isScanning: Bool = false

    // MARK: - BLE Core
    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?

    // MARK: - Constants
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")
    private let bodySensorLocationCharacteristicUUID = CBUUID(string: "2A38")
    private let deviceInfoServiceUUID = CBUUID(string: "180A")
    private let manufacturerNameCharacteristicUUID = CBUUID(string: "2A29")

    // MARK: - External event hooks
    var onConnect: (() -> Void)?
    var onHeartRateUpdate: ((UInt16) -> Void)?

    // MARK: - Init
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - BLE Connect + Scan
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        discoveredPeripherals.removeAll()
        isScanning = true

        // Scan for all devices
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    func connectToPeripheral(_ peripheral: CBPeripheral) {
        stopScanning()
        heartRatePeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    /// 🔗 NEW: Connect directly to known device UUID
    func connectToPeripheral(with uuid: UUID) {
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let knownPeripheral = peripherals.first {
            print("🔗 Connecting to known peripheral: \(knownPeripheral.name ?? "Unknown") with UUID \(uuid)")
            connectToPeripheral(knownPeripheral)
        } else {
            print("❌ Could not retrieve peripheral with UUID: \(uuid)")
            // Optional fallback:
            // startScanning()
        }
    }

    func disconnectCurrentPeripheral() {
        if let peripheral = heartRatePeripheral, isConnected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension HeartRateManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on")
        case .poweredOff:
            print("⚠️ Bluetooth is powered off")
            connected = "Please turn on Bluetooth"
            isConnected = false
        case .unauthorized:
            print("⚠️ Bluetooth unauthorized")
            connected = "Bluetooth permission is required"
        case .unsupported:
            print("❌ Bluetooth not supported")
            connected = "This device does not support Bluetooth"
        case .resetting:
            print("⚠️ Bluetooth resetting")
        case .unknown:
            print("⚠️ Bluetooth state unknown")
        @unknown default:
            print("⚠️ Unhandled Bluetooth state")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        if let name = peripheral.name, !name.isEmpty {
            print("🔍 Found device: \(name) UUID: \(peripheral.identifier)")
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                DispatchQueue.main.async {
                    self.discoveredPeripherals.append(peripheral)
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "Unknown")")
        DispatchQueue.main.async {
            self.connected = "Connected: YES"
            self.isConnected = true
            self.onConnect?()
        }
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown")")
        DispatchQueue.main.async {
            self.connected = "Connected: NO"
            self.isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("⚠️ Disconnected from \(peripheral.name ?? "Unknown")")
        DispatchQueue.main.async {
            self.connected = "Connected: NO"
            self.isConnected = false
            self.heartRate = 0
        }
    }
}

// MARK: - CBPeripheralDelegate
extension HeartRateManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }

        if service.uuid == heartRateServiceUUID {
            for characteristic in characteristics {
                switch characteristic.uuid {
                case heartRateMeasurementCharacteristicUUID:
                    peripheral.setNotifyValue(true, for: characteristic)
                case bodySensorLocationCharacteristicUUID:
                    peripheral.readValue(for: characteristic)
                default:
                    break
                }
            }
        } else if service.uuid == deviceInfoServiceUUID {
            for characteristic in characteristics {
                if characteristic.uuid == manufacturerNameCharacteristicUUID {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            print("❌ Characteristic update error: \(error!.localizedDescription)")
            return
        }

        switch characteristic.uuid {
        case heartRateMeasurementCharacteristicUUID:
            getHeartRateBPM(from: characteristic)
        case bodySensorLocationCharacteristicUUID:
            getBodyLocation(from: characteristic)
        case manufacturerNameCharacteristicUUID:
            getManufacturerName(from: characteristic)
        default:
            break
        }
    }

    // MARK: - Characteristic Parsing
    private func getHeartRateBPM(from characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }

        var bpm: UInt16 = 0
        let firstByte = data[0]

        if (firstByte & 0x01) == 0 {
            bpm = UInt16(data[1])
        } else {
            bpm = UInt16(data[1]) | (UInt16(data[2]) << 8)
        }

//        print("❤️ Heart Rate: \(bpm) BPM")

        DispatchQueue.main.async {
            self.heartRate = bpm
            self.onHeartRateUpdate?(bpm)
        }
    }

    private func getBodyLocation(from characteristic: CBCharacteristic) {
        guard let data = characteristic.value, let byte = data.first else {
            self.bodyLocation = "Body Location: N/A"
            return
        }

        DispatchQueue.main.async {
            switch byte {
            case 1:
                self.bodyLocation = "Body Location: Chest"
            default:
                self.bodyLocation = "Body Location: Undefined"
            }
        }
    }

    private func getManufacturerName(from characteristic: CBCharacteristic) {
        guard let data = characteristic.value else {
            self.manufacturer = "Manufacturer: Unknown"
            return
        }

        let name = String(data: data, encoding: .utf8) ?? "Unknown"
        DispatchQueue.main.async {
            self.manufacturer = "Manufacturer: \(name)"
        }
    }
}
