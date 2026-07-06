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
    // Holds a connect request made before the central reached .poweredOn or
    // before the peripheral has been seen, so we can complete it asynchronously.
    private var pendingConnectionUUID: UUID?
    private var pendingConnectScanTimer: Timer?
    private let pendingConnectScanTimeout: TimeInterval = 15.0

    // MARK: - Constants
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")
    private let bodySensorLocationCharacteristicUUID = CBUUID(string: "2A38")
    private let deviceInfoServiceUUID = CBUUID(string: "180A")
    private let manufacturerNameCharacteristicUUID = CBUUID(string: "2A29")

    // MARK: - External event hooks
    var onConnect: (() -> Void)?
    var onHeartRateUpdate: ((UInt16) -> Void)?
    var onDisconnect: (() -> Void)?   // fired on a BLE-level drop (strap off/died)

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
//        print(self.heartRateServiceUUID)
    }

    /// 🔗 Connect directly to a known device UUID.
    /// Safe to call before the central is `.poweredOn`, and safe even if the system
    /// has not cached the peripheral — falls back to a service-UUID scan with a timeout.
    func connectToPeripheral(with uuid: UUID) {
        pendingConnectionUUID = uuid
        if centralManager.state == .poweredOn {
            attemptPendingConnection()
        } else {
            print("⏳ Connect request queued for UUID \(uuid) — waiting for Bluetooth (state=\(centralManager.state.rawValue))")
        }
    }

    private func attemptPendingConnection() {
        guard let uuid = pendingConnectionUUID else { return }

        // 1. Fast path: peripheral is in CoreBluetooth's cache.
        if let knownPeripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            print("🔗 Connecting to known peripheral: \(knownPeripheral.name ?? "Unknown") with UUID \(uuid)")
            finishPendingConnect(to: knownPeripheral)
            return
        }

        // 2. Already-connected path: the system holds an HR-service link for this UUID.
        let connectedHR = centralManager.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID])
        if let connectedPeripheral = connectedHR.first(where: { $0.identifier == uuid }) {
            print("🔗 Connecting to already-connected peripheral with UUID \(uuid)")
            finishPendingConnect(to: connectedPeripheral)
            return
        }

        // 3. Fallback: scan for it. didDiscover will close the loop when it appears.
        print("⚠️ Peripheral \(uuid) not in CB cache — scanning for it (timeout \(Int(pendingConnectScanTimeout))s)")
        startPendingConnectScan()
    }

    private func finishPendingConnect(to peripheral: CBPeripheral) {
        pendingConnectionUUID = nil
        stopPendingConnectScan()
        connectToPeripheral(peripheral)
    }

    private func startPendingConnectScan() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)

        pendingConnectScanTimer?.invalidate()
        pendingConnectScanTimer = Timer.scheduledTimer(
            withTimeInterval: pendingConnectScanTimeout, repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            let uuidString = self.pendingConnectionUUID?.uuidString ?? "?"
            print("⌛️ Connect-scan timed out for UUID \(uuidString) — giving up; user can retry")
            self.pendingConnectionUUID = nil
            self.stopPendingConnectScan()
        }
    }

    private func stopPendingConnectScan() {
        pendingConnectScanTimer?.invalidate()
        pendingConnectScanTimer = nil
        if isScanning {
            centralManager.stopScan()
            isScanning = false
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
            // Drain any connect request that arrived before the central was ready.
            attemptPendingConnection()
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
        // Pending-connect first: name is often absent in adv packets, don't gate on it.
        if let pendingUUID = pendingConnectionUUID, peripheral.identifier == pendingUUID {
            print("🎯 Pending peripheral discovered, connecting: \(peripheral.identifier)")
            finishPendingConnect(to: peripheral)
            return
        }

        if let name = peripheral.name, !name.isEmpty {
            print("🔍 Found device: \(name) UUID: \(peripheral.identifier)")
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(peripheral)
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
            // Tell the owning view model: without this, a physical strap death
            // left the player looking connected and the motor running on the
            // last BPM. Hardware and monitor must be twins.
            self.onDisconnect?()
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
        guard let data = characteristic.value, data.count >= 2 else { return }

        // Per BLE Heart Rate Measurement spec (0x2A37): byte 0 = flags,
        // bit 0 selects UInt8 vs UInt16 BPM value, then 1 or 2 bytes follow.
        var bpm: UInt16 = 0
        let flags = data[0]
        if (flags & 0x01) == 0 {
            bpm = UInt16(data[1])
        } else if data.count >= 3 {
            bpm = UInt16(data[1]) | (UInt16(data[2]) << 8)
        }

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
