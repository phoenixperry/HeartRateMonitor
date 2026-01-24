import SwiftUI

struct ConfigurationScreen: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var gameStateManager: GameStateManager
    @State private var showResetAlert = false
    @State private var showRemoveAlert = false
    @State private var deviceToRemove: UUID?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Device Configuration")
                .font(.largeTitle)
                .bold()
                .padding(.top)

            // Player count stepper
            HStack {
                Text("Number of Players:")
                Stepper(
                    "\(configManager.config.playerCount)",
                    value: Binding(
                        get: { configManager.config.playerCount },
                        set: { configManager.setPlayerCount($0) }
                    ),
                    in: AppConfiguration.minPlayers...AppConfiguration.maxPlayers
                )
                .frame(width: 120)
            }
            .padding(.horizontal)

            Divider()

            // Main content in two columns
            HStack(alignment: .top, spacing: 30) {
                // Left column: Device list
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Discovered Devices")
                            .font(.headline)
                        Spacer()
                        if configManager.isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Device list
                    List {
                        if configManager.discoveredDevices.isEmpty && !configManager.isScanning {
                            Text("No devices found. Tap 'Scan' to search.")
                                .foregroundColor(.secondary)
                                .italic()
                        }

                        ForEach(configManager.discoveredDevices) { device in
                            DeviceRow(
                                device: device,
                                configManager: configManager,
                                onRemove: {
                                    deviceToRemove = device.uuid
                                    showRemoveAlert = true
                                }
                            )
                        }

                        // Show paired but offline devices
                        ForEach(offlinePairedDevices, id: \.uuid) { monitor in
                            OfflineDeviceRow(monitor: monitor, configManager: configManager)
                        }
                    }
                    .frame(minHeight: 200)
                    .listStyle(.bordered)

                    Button(action: { configManager.startScan() }) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Scan for Devices")
                        }
                    }
                    .disabled(configManager.isScanning || configManager.bluetoothState != .poweredOn)

                    if configManager.bluetoothState != .poweredOn {
                        Text("Bluetooth is not available")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .frame(minWidth: 300)

                Divider()

                // Right column: Player assignments
                VStack(alignment: .leading, spacing: 10) {
                    Text("Player Assignments")
                        .font(.headline)

                    ForEach(1...configManager.config.playerCount, id: \.self) { playerNum in
                        PlayerSlotPicker(
                            playerNumber: playerNum,
                            configManager: configManager
                        )
                    }

                    Spacer()

                    // Validation status
                    if !configManager.configurationNeeded {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Configuration complete!")
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Assign devices to all \(configManager.config.playerCount) players")
                        }
                    }
                }
                .frame(minWidth: 300)
            }
            .padding()

            Divider()

            // Action buttons
            HStack(spacing: 20) {
                Button("Reset All") {
                    showResetAlert = true
                }
                .foregroundColor(.red)

                Spacer()

                Button("Cancel") {
                    gameStateManager.closeConfiguration()
                }

                Button("Save & Continue") {
                    configManager.saveConfig()
                    gameStateManager.closeConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .disabled(configManager.configurationNeeded)
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
        .padding()
        .alert("Reset Configuration?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                configManager.resetConfig()
            }
        } message: {
            Text("This will remove all paired devices and assignments.")
        }
        .alert("Remove Device?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {
                deviceToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let uuid = deviceToRemove {
                    configManager.removeMonitor(uuid: uuid)
                }
                deviceToRemove = nil
            }
        } message: {
            Text("This will remove the device from your paired list.")
        }
        .onAppear {
            // Auto-scan when configuration screen opens
            if configManager.bluetoothState == .poweredOn {
                configManager.startScan()
            }
        }
    }

    // Paired devices that aren't currently discovered
    var offlinePairedDevices: [MonitorDevice] {
        configManager.config.monitors.filter { monitor in
            !configManager.discoveredDevices.contains { $0.uuid == monitor.uuid }
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: DiscoveredDevice
    @ObservedObject var configManager: ConfigurationManager
    var onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .fontWeight(device.isPaired ? .semibold : .regular)
                Text(device.uuid.uuidString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status badge
            Text(device.statusText)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .cornerRadius(4)

            // Action button
            if device.isPaired {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Remove device")
            } else {
                Button(action: { configManager.addMonitor(from: device) }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Add device")
            }
        }
        .padding(.vertical, 4)
    }

    var statusColor: Color {
        if device.isSelected { return .blue }
        if device.isPaired { return .green }
        return .gray
    }
}

// MARK: - Offline Device Row

struct OfflineDeviceRow: View {
    let monitor: MonitorDevice
    @ObservedObject var configManager: ConfigurationManager

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(monitor.name)
                Text(monitor.uuid.uuidString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Offline")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(4)

            Button(action: { configManager.removeMonitor(uuid: monitor.uuid) }) {
                Image(systemName: "minus.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .opacity(0.7)
    }
}

// MARK: - Player Slot Picker

struct PlayerSlotPicker: View {
    let playerNumber: Int
    @ObservedObject var configManager: ConfigurationManager

    var body: some View {
        HStack {
            Text("Player \(playerNumber):")
                .frame(width: 80, alignment: .leading)

            Picker("", selection: selectedBinding) {
                Text("-- Select Device --").tag(nil as UUID?)

                ForEach(availableMonitors, id: \.uuid) { monitor in
                    HStack {
                        Text(monitor.name)
                        if isDeviceAvailable(monitor.uuid) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 8))
                        }
                    }
                    .tag(monitor.uuid as UUID?)
                }
            }
            .frame(minWidth: 200)
        }
    }

    var selectedBinding: Binding<UUID?> {
        Binding(
            get: {
                let index = playerNumber - 1
                guard index < configManager.config.selectedPlayerUUIDs.count else { return nil }
                return configManager.config.selectedPlayerUUIDs[index]
            },
            set: { newValue in
                updateSelection(newValue)
            }
        )
    }

    // Monitors that can be assigned to this slot
    // (all paired monitors that aren't assigned to other players)
    var availableMonitors: [MonitorDevice] {
        configManager.config.monitors.filter { monitor in
            // Include if not assigned, or if assigned to this player
            let currentSelection = selectedBinding.wrappedValue
            if monitor.uuid == currentSelection { return true }
            return !configManager.config.selectedPlayerUUIDs.contains(monitor.uuid)
        }
    }

    func isDeviceAvailable(_ uuid: UUID) -> Bool {
        configManager.discoveredDevices.contains { $0.uuid == uuid }
    }

    func updateSelection(_ newValue: UUID?) {
        let index = playerNumber - 1

        // Ensure array is properly sized
        var uuids = configManager.config.selectedPlayerUUIDs

        // Remove any existing assignment of this UUID
        if let uuid = newValue {
            uuids.removeAll { $0 == uuid }
        }

        // Resize array if needed
        while uuids.count <= index {
            // Use a placeholder approach - we need to handle sparse arrays
            // For simplicity, we'll just ensure the array has enough elements
            if let first = configManager.config.monitors.first(where: { m in !uuids.contains(m.uuid) }) {
                uuids.append(first.uuid)
            } else {
                break
            }
        }

        if let uuid = newValue {
            if index < uuids.count {
                uuids[index] = uuid
            } else {
                uuids.append(uuid)
            }
        } else if index < uuids.count {
            uuids.remove(at: index)
        }

        configManager.config.selectedPlayerUUIDs = uuids
        configManager.saveConfig()
    }
}

#Preview {
    ConfigurationScreen(
        configManager: ConfigurationManager(),
        gameStateManager: GameStateManager(
            espManager: ESPPeripheralManager(),
            configManager: ConfigurationManager()
        )
    )
}
