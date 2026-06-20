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

    /// Background prober that briefly connects to each paired monitor to see
    /// whether it's actually streaming non-zero BPM (i.e. on a person), as
    /// opposed to just sitting on a charger and advertising BLE. Drives the
    /// black "live" dot in the Player Assignments dropdown.
    let livenessProber = MonitorLivenessProber()
    private var liveSubscription: AnyCancellable?
    /// Bumped every time the prober's live set changes so SwiftUI views that
    /// read `isDeviceLive(_:)` recompute. Cheaper than republishing each UUID.
    @Published private(set) var livenessTick: Int = 0

    /// True if the given monitor has reported a non-zero BPM during the most
    /// recent probe — i.e. it is currently being worn / measuring.
    func isDeviceLive(_ uuid: UUID) -> Bool {
        livenessProber.liveUUIDs.contains(uuid)
    }

    /// Begin live-probing the currently paired monitors. Call from the
    /// Configuration screen's onAppear so probing only runs while the user
    /// is actively choosing assignments.
    func startLivenessProbing() {
        let uuids = config.monitors.map { $0.uuid }
        livenessProber.start(monitoringUUIDs: uuids)
    }

    /// Cancel any in-flight probes. Call from the Configuration screen's
    /// onDisappear so we don't fight with per-player connections during
    /// gameplay.
    func stopLivenessProbing() {
        livenessProber.stop()
    }

    // MARK: - Computed Properties

    /// Returns true if configuration screen should be shown
    var configurationNeeded: Bool {
        // Simulation mode bypasses device configuration
        if UserDefaults.standard.bool(forKey: "SimulateHeartRateMonitors") {
            return false
        }
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

        print("📂 Config path: \(configURL.path)")

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            print("📂 Directory ensured at: \(appFolder.path)")
        } catch {
            print("⚠️ Failed to create directory: \(error)")
        }

        // Check if file exists before loading
        let fileExists = FileManager.default.fileExists(atPath: configURL.path)
        print("📂 Config file exists: \(fileExists)")

        // Load or create config
        if let loadedConfig = Self.loadConfig(from: configURL) {
            self.config = loadedConfig
            print("✅ Loaded existing config: \(loadedConfig.monitors.count) monitors, \(loadedConfig.selectedPlayerUUIDs.count) selected, playerCount: \(loadedConfig.playerCount)")
        } else {
            self.config = .empty
            print("📝 Starting with empty config (no existing file found)")
        }

        super.init()

        // Initialize Bluetooth
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Republish prober's liveness changes through this object so SwiftUI
        // views observing `ConfigurationManager` re-render when the set flips.
        liveSubscription = livenessProber.$liveUUIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.livenessTick &+= 1
            }
    }

    // MARK: - Config Persistence

    private static func loadConfig(from url: URL) -> AppConfiguration? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("📁 No config file found, will create new one")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(AppConfiguration.self, from: data)
            print("📁 Loaded config with \(config.monitors.count) monitors, \(config.selectedPlayerUUIDs.count) selected")
            return config
        } catch {
            print("⚠️ Failed to decode config: \(error)")
            print("⚠️ Keeping existing file, starting with empty config")
            // Don't delete the file - user might want to recover it
            return nil
        }
    }

    func saveConfig() {
        // Don't save empty config if a file already exists (prevents accidental overwrites)
        if config.monitors.isEmpty && config.selectedPlayerUUIDs.isEmpty {
            if FileManager.default.fileExists(atPath: configURL.path) {
                print("⚠️ Skipping save: won't overwrite existing config with empty config")
                return
            }
        }

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

        // Surface already-connected peripherals up front. They won't appear in scan
        // callbacks because connected peripherals stop advertising.
        refreshConnectedDevices()

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

    /// Surface peripherals that the system already has connected for the heart rate service.
    /// A connected strap stops advertising, so scanning alone will never see it — but it's
    /// absolutely "online" from the user's point of view. Merging these into discoveredDevices
    /// makes them show as "Assigned" / "Paired" rather than "Offline".
    func refreshConnectedDevices() {
        guard centralManager.state == .poweredOn else { return }

        let connected = centralManager.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID])
        for peripheral in connected {
            // Don't double-insert if the scan already saw it.
            if discoveredDevices.contains(where: { $0.uuid == peripheral.identifier }) { continue }

            // Prefer the live CB name, then the name we stored when pairing, then a placeholder.
            let displayName = peripheral.name ?? config.monitor(for: peripheral.identifier)?.name ?? "Unknown Device"
            let device = DiscoveredDevice(peripheral: peripheral, name: displayName, rssi: 0)
            discoveredDevices.append(device)
            print("🔗 Surfaced already-connected peripheral: \(displayName) (\(peripheral.identifier))")

            if config.monitors.contains(where: { $0.uuid == peripheral.identifier }) {
                updateLastSeen(for: peripheral.identifier)
            }
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
        if let index = config.monitors.firstIndex(where: { $0.uuid == device.uuid }) {
            config.monitors[index].name = device.name
            config.monitors[index].lastSeen = Date()
        } else {
            let monitor = MonitorDevice(uuid: device.uuid, name: device.name)
            config.monitors.append(monitor)
            print("➕ Added monitor: \(device.name)")
        }
        saveConfig()
    }

    func removeMonitor(uuid: UUID) {
        config.monitors.removeAll { $0.uuid == uuid }
        config.selectedPlayerUUIDs.removeAll { $0 == uuid }
        saveConfig()
        print("➖ Removed monitor: \(uuid)")
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
        let isPairedUUID = config.monitors.contains { $0.uuid == peripheral.identifier }

        // Skip if no name
        guard let name = peripheral.name, !name.isEmpty else { return }

        // Skip duplicates
        guard !discoveredDevices.contains(where: { $0.uuid == peripheral.identifier }) else { return }

        // Re-check inside the same synchronous tick we're about to mutate on.
        // Delegate already runs on main (CBCentralManager init used queue: nil),
        // so the check and append must be atomic — no async hop between them.
        guard !discoveredDevices.contains(where: { $0.uuid == peripheral.identifier }) else { return }

        let device = DiscoveredDevice(peripheral: peripheral, rssi: RSSI.intValue)
        discoveredDevices.append(device)
        print("🔍 Discovered: \(name) (\(peripheral.identifier)) RSSI: \(RSSI)")

        if isPairedUUID {
            updateLastSeen(for: peripheral.identifier)
        }
    }
}
