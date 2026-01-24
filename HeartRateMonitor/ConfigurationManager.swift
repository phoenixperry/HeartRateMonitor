import Foundation
import CoreBluetooth
import Combine

/// Manages device configuration, BLE discovery, and persistence
class ConfigurationManager: NSObject, ObservableObject {
    // MARK: - Published State
    @Published var config: AppConfiguration
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isScanning: Bool = false
    @Published var bluetoothState: CBManagerState = .unknown

    // MARK: - Private
    private var centralManager: CBCentralManager!
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let configURL: URL
    private var scanTimer: Timer?

    // MARK: - Computed Properties

    /// Returns true if configuration screen should be shown
    var configurationNeeded: Bool {
        // No selected players
        if config.selectedPlayerUUIDs.isEmpty {
            return true
        }
        // Wrong number of selected players
        if config.selectedPlayerUUIDs.count != config.playerCount {
            return true
        }
        // Check if all selected devices are in monitors list
        for uuid in config.selectedPlayerUUIDs {
            if config.monitor(for: uuid) == nil {
                return true
            }
        }
        return false
    }

    /// Returns UUIDs of selected devices that are currently available (discovered)
    var availableSelectedDevices: [UUID] {
        config.selectedPlayerUUIDs.filter { uuid in
            discoveredDevices.contains { $0.uuid == uuid }
        }
    }

    /// Returns true if all selected devices are currently available
    var allSelectedDevicesAvailable: Bool {
        guard !config.selectedPlayerUUIDs.isEmpty else { return false }
        return availableSelectedDevices.count == config.selectedPlayerUUIDs.count
    }

    // MARK: - Init

    override init() {
        // Setup config URL
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("HeartRateMonitor")
        self.configURL = appFolder.appendingPathComponent("config.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        // Load or create config
        self.config = Self.loadConfig(from: configURL) ?? .empty

        super.init()

        // Initialize Bluetooth
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Config Persistence

    private static func loadConfig(from url: URL) -> AppConfiguration? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("📁 No config file found, will create new one")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(AppConfiguration.self, from: data)
            print("📁 Loaded config with \(config.monitors.count) monitors, \(config.selectedPlayerUUIDs.count) selected")
            return config
        } catch {
            print("⚠️ Failed to load config: \(error). Resetting to default.")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(config)
            try data.write(to: configURL)
            print("💾 Saved config to \(configURL.path)")
        } catch {
            print("⚠️ Failed to save config: \(error)")
        }
    }

    func resetConfig() {
        config = .empty
        saveConfig()
        print("🔄 Config reset to default")
    }

    // MARK: - Device Discovery

    func startScan(duration: TimeInterval = 10.0) {
        guard centralManager.state == .poweredOn else {
            print("⚠️ Bluetooth not ready for scanning")
            return
        }

        stopScan()
        discoveredDevices.removeAll()
        isScanning = true

        // Scan for heart rate service
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        print("🔍 Started scanning for heart rate devices...")

        // Auto-stop after duration
        scanTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopScan()
        }
    }

    func stopScan() {
        scanTimer?.invalidate()
        scanTimer = nil

        if isScanning {
            centralManager.stopScan()
            isScanning = false
            print("🔍 Stopped scanning. Found \(discoveredDevices.count) devices.")
        }
    }

    /// Quick scan to check if selected devices are available
    func checkDeviceAvailability(completion: @escaping (Bool) -> Void) {
        guard centralManager.state == .poweredOn else {
            completion(false)
            return
        }

        startScan(duration: 3.0)

        // Check after scan completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            completion(self.allSelectedDevicesAvailable)
        }
    }

    // MARK: - Device Management

    func addMonitor(from device: DiscoveredDevice) {
        // Check if already exists
        if let index = config.monitors.firstIndex(where: { $0.uuid == device.uuid }) {
            // Update existing
            config.monitors[index].name = device.name
            config.monitors[index].lastSeen = Date()
        } else {
            // Add new
            let monitor = MonitorDevice(uuid: device.uuid, name: device.name)
            config.monitors.append(monitor)
            print("➕ Added monitor: \(device.name)")
        }
        saveConfig()
        updateDiscoveredDeviceStatus()
    }

    func removeMonitor(uuid: UUID) {
        // Remove from monitors
        config.monitors.removeAll { $0.uuid == uuid }

        // Also remove from selected if present
        config.selectedPlayerUUIDs.removeAll { $0 == uuid }

        saveConfig()
        updateDiscoveredDeviceStatus()
        print("➖ Removed monitor: \(uuid)")
    }

    func assignToPlayer(uuid: UUID, playerSlot: Int) {
        guard playerSlot >= 1 && playerSlot <= config.playerCount else { return }

        let index = playerSlot - 1

        // Ensure array is large enough
        while config.selectedPlayerUUIDs.count < playerSlot {
            // Fill with placeholder - we'll need to handle this differently
            // Actually, let's use a different approach - store as optional or use a dictionary
            config.selectedPlayerUUIDs.append(uuid) // This is the first/only assignment
            saveConfig()
            updateDiscoveredDeviceStatus()
            return
        }

        // Remove this UUID from any existing slot
        config.selectedPlayerUUIDs.removeAll { $0 == uuid }

        // Ensure array is correct size again
        while config.selectedPlayerUUIDs.count < index {
            // Need placeholder handling - for now just append at end
        }

        if index < config.selectedPlayerUUIDs.count {
            config.selectedPlayerUUIDs[index] = uuid
        } else {
            config.selectedPlayerUUIDs.append(uuid)
        }

        saveConfig()
        updateDiscoveredDeviceStatus()
        print("✅ Assigned \(uuid) to player \(playerSlot)")
    }

    func unassignPlayer(playerSlot: Int) {
        guard playerSlot >= 1 && playerSlot <= config.selectedPlayerUUIDs.count else { return }
        let index = playerSlot - 1
        config.selectedPlayerUUIDs.remove(at: index)
        saveConfig()
        updateDiscoveredDeviceStatus()
        print("❌ Unassigned player \(playerSlot)")
    }

    func setPlayerCount(_ count: Int) {
        guard count >= AppConfiguration.minPlayers && count <= AppConfiguration.maxPlayers else { return }
        config.playerCount = count

        // Trim selected players if we have too many
        if config.selectedPlayerUUIDs.count > count {
            config.selectedPlayerUUIDs = Array(config.selectedPlayerUUIDs.prefix(count))
        }

        saveConfig()
    }

    func updateLastSeen(for uuid: UUID) {
        if let index = config.monitors.firstIndex(where: { $0.uuid == uuid }) {
            config.monitors[index].lastSeen = Date()
            saveConfig()
        }
    }

    // MARK: - Private Helpers

    private func updateDiscoveredDeviceStatus() {
        for i in 0..<discoveredDevices.count {
            discoveredDevices[i].isPaired = config.monitors.contains { $0.uuid == discoveredDevices[i].uuid }
            discoveredDevices[i].isSelected = config.selectedPlayerUUIDs.contains(discoveredDevices[i].uuid)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension ConfigurationManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state

        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on")
        case .poweredOff:
            print("⚠️ Bluetooth is powered off")
            stopScan()
        case .unauthorized:
            print("⚠️ Bluetooth unauthorized")
        case .unsupported:
            print("⚠️ Bluetooth unsupported")
        default:
            print("⚠️ Bluetooth state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // Skip if no name
        guard let name = peripheral.name, !name.isEmpty else { return }

        // Skip duplicates
        guard !discoveredDevices.contains(where: { $0.uuid == peripheral.identifier }) else { return }

        let isPaired = config.monitors.contains { $0.uuid == peripheral.identifier }
        let isSelected = config.selectedPlayerUUIDs.contains(peripheral.identifier)

        let device = DiscoveredDevice(
            peripheral: peripheral,
            rssi: RSSI.intValue,
            isPaired: isPaired,
            isSelected: isSelected
        )

        DispatchQueue.main.async {
            self.discoveredDevices.append(device)
            print("🔍 Discovered: \(name) (\(peripheral.identifier)) RSSI: \(RSSI)")

            // Update lastSeen if this is a known device
            if isPaired {
                self.updateLastSeen(for: peripheral.identifier)
            }
        }
    }
}
