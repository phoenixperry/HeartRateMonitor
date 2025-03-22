import Foundation
import CoreBluetooth
import Combine

class HeartRateManager: NSObject, ObservableObject {
    // Published properties for SwiftUI to observe
    @Published var heartRate: UInt16 = 0
    @Published var connected: String = ""
    @Published var bodyLocation: String = ""
    @Published var manufacturer: String = ""
    @Published var isConnected: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var isScanning: Bool = false
    
    // BLE properties
    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?
    
    // Constants for BLE UUIDs
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")
    private let bodySensorLocationCharacteristicUUID = CBUUID(string: "2A38")
    private let deviceInfoServiceUUID = CBUUID(string: "180A")
    private let manufacturerNameCharacteristicUUID = CBUUID(string: "2A29")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            // Clear previous results when starting a new scan
            discoveredPeripherals.removeAll()
            isScanning = true
            
            // Scan for all devices (nil services means scan for all)
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
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
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            connected = "Please turn on Bluetooth"
            isConnected = false
        case .unauthorized:
            print("Bluetooth is unauthorized")
            connected = "Bluetooth permission is required"
        case .unsupported:
            print("Bluetooth is not supported")
            connected = "Bluetooth is not supported on this device"
        case .resetting:
            print("Bluetooth is resetting")
        case .unknown:
            print("Bluetooth state unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        
        // Add device to our list if it has a name and isn't already in the list
        if let name = peripheral.name, !name.isEmpty {
            print("Found device: \(name) with UUID: \(peripheral.identifier)")
            
            // Check if this device is already in our list
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                DispatchQueue.main.async {
                    self.discoveredPeripherals.append(peripheral)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connected = "Connected: YES"
            self.isConnected = true
        }
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        DispatchQueue.main.async {
            self.connected = "Connected: NO"
            self.isConnected = false
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
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
                if characteristic.uuid == heartRateMeasurementCharacteristicUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == bodySensorLocationCharacteristicUUID {
                    peripheral.readValue(for: characteristic)
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
            print("Error updating characteristic: \(error?.localizedDescription ?? "unknown error")")
            return
        }
        
        if characteristic.uuid == heartRateMeasurementCharacteristicUUID {
            getHeartRateBPM(from: characteristic)
        } else if characteristic.uuid == bodySensorLocationCharacteristicUUID {
            getBodyLocation(from: characteristic)
        } else if characteristic.uuid == manufacturerNameCharacteristicUUID {
            getManufacturerName(from: characteristic)
        }
    }
    
    // MARK: - Characteristic Parsing
    private func getHeartRateBPM(from characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        let reportData = data

        var bpm: UInt16 = 0
        
        // The first byte indicates the format of the heart rate value
        let firstByte = reportData[0]
        if (firstByte & 0x01) == 0 {
            // Heart Rate Value Format is in the 2nd byte
            bpm = UInt16(reportData[1])
        } else {
            // Heart Rate Value Format is in the 2nd and 3rd bytes
            bpm = UInt16(reportData[1]) | (UInt16(reportData[2]) << 8)
        }
        print("❤️ Heart Rate: \(bpm) BPM")
        DispatchQueue.main.async {
            self.heartRate = bpm
        }
    }
    
    private func getBodyLocation(from characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        
        if let bodySensor = data.first {
            DispatchQueue.main.async {
                switch bodySensor {
                case 1:
                    self.bodyLocation = "Body Location: Chest"
                default:
                    self.bodyLocation = "Body Location: Undefined"
                }
            }
        } else {
            DispatchQueue.main.async {
                self.bodyLocation = "Body Location: N/A"
            }
        }
    }
    
    private func getManufacturerName(from characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        
        if let name = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.manufacturer = "Manufacturer: \(name)"
            }
        } else {
            DispatchQueue.main.async {
                self.manufacturer = "Manufacturer: Unknown"
            }
        }
    }
    
}
