import SwiftUI
import CoreBluetooth

struct ConfigurationScreen: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var gameStateManager: GameStateManager
    @State private var showResetAlert = false
    @State private var showRemoveAlert = false
    @State private var deviceToRemove: UUID?
    @State private var researchLoggingEnabled = ResearchLogger.shared.isEnabled
    @State private var simulationEnabled = UserDefaults.standard.bool(forKey: "SimulateHeartRateMonitors")
    @State private var miniFreakEnabled = UserDefaults.standard.bool(forKey: "EnableMiniFreakEngine")

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            content
        }
        .tint(Palette.ink)
        // Force light appearance inside this view so system widgets (Toggle labels,
        // alert text, etc.) resolve Color.primary to black against the white canvas.
        // Without this, Color.primary becomes white in system dark mode and labels
        // vanish against the forced-white background.
        .preferredColorScheme(.light)
    }

    private var content: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Eyebrow(text: "Settings")
                Text("Device configuration")
                    .font(Type.display(28, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .kerning(-0.4)
            }
            .padding(.top, 8)

            // Player count — custom monochrome stepper.
            HStack(spacing: 16) {
                Text("Number of players")
                    .font(Type.sans(12, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Palette.muted)

                MonochromeStepper(
                    value: configManager.config.playerCount,
                    range: AppConfiguration.minPlayers...AppConfiguration.maxPlayers,
                    onChange: { configManager.setPlayerCount($0) }
                )
            }
            .padding(.horizontal)

            Hairline()
                .padding(.vertical, 4)

            // Main content in two columns
            HStack(alignment: .top, spacing: 36) {
                // Left column: Device list
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeading(
                            title: "Discovered devices",
                            detail: configManager.discoveredDevices.isEmpty ? nil : "\(configManager.discoveredDevices.count)"
                        )
                        Spacer()
                        if configManager.isScanning {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(Palette.ink)
                            Text("Scanning…")
                                .font(Type.sans(11))
                                .foregroundColor(Palette.muted)
                        }
                    }

                    // Device list — manual scroll/stack so we have full control of bg + border.
                    ScrollView {
                        VStack(spacing: 0) {
                            if configManager.discoveredDevices.isEmpty && offlinePairedDevices.isEmpty && !configManager.isScanning {
                                Text("No devices found. Tap 'Scan' to search.")
                                    .font(Type.sans(12))
                                    .italic()
                                    .foregroundColor(Palette.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                            }

                            ForEach(Array(configManager.discoveredDevices.enumerated()), id: \.element.id) { index, device in
                                if index > 0 { Hairline() }
                                DeviceRow(
                                    device: device,
                                    configManager: configManager,
                                    onRemove: {
                                        deviceToRemove = device.uuid
                                        showRemoveAlert = true
                                    }
                                )
                                .padding(.horizontal, 14)
                            }

                            if !configManager.discoveredDevices.isEmpty && !offlinePairedDevices.isEmpty {
                                Hairline()
                            }

                            ForEach(Array(offlinePairedDevices.enumerated()), id: \.element.uuid) { index, monitor in
                                if index > 0 { Hairline() }
                                OfflineDeviceRow(monitor: monitor, configManager: configManager)
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                    .frame(minHeight: 200)
                    .background(Palette.canvas)
                    .bwOutline(1)

                    Button {
                        configManager.startScan()
                    } label: {
                        Text("Scan for devices")
                    }
                    .buttonStyle(BWOutlineButtonStyle(minWidth: 200, height: 38))
                    .disabled(configManager.isScanning || configManager.bluetoothState != .poweredOn)
                    .opacity((configManager.isScanning || configManager.bluetoothState != .poweredOn) ? 0.4 : 1)

                    if configManager.bluetoothState != .poweredOn {
                        Text("Bluetooth is not available")
                            .font(Type.sans(11))
                            .foregroundColor(Palette.ink)
                    }
                }
                .frame(minWidth: 300)

                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 1)
                    .padding(.vertical, 4)

                // Right column: Player assignments
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(
                        title: "Player assignments",
                        detail: "\(configManager.config.selectedPlayerUUIDs.count)/\(configManager.config.playerCount)"
                    )

                    VStack(spacing: 0) {
                        ForEach(Array((1...configManager.config.playerCount).enumerated()), id: \.element) { index, playerNum in
                            if index > 0 { Hairline() }
                            PlayerSlotPicker(
                                playerNumber: playerNum,
                                configManager: configManager
                            )
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Palette.canvas)
                    .bwOutline(1)

                    Spacer()
                }
                .frame(minWidth: 300)
            }
            .disabled(simulationEnabled)
            .opacity(simulationEnabled ? 0.4 : 1.0)
            .padding(.vertical, 8)

            Hairline()
                .padding(.vertical, 8)

            // Development settings — full width, flush left.
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: "Development settings")

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Simulate Heart Rate Monitors", isOn: $simulationEnabled)
                        .toggleStyle(RadialToggleStyle())
                        .onChange(of: simulationEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "SimulateHeartRateMonitors")
                            if newValue {
                                researchLoggingEnabled = false
                                ResearchLogger.shared.isEnabled = false
                            }
                        }

                    Text("Simulated BPM data is generated for all players without needing physical Bluetooth heart rate monitors.")
                        .font(Type.sans(11))
                        .foregroundColor(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 24)   // line up with toggle label
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        Toggle("Drive Arturia MiniFreak V", isOn: $miniFreakEnabled)
                            .toggleStyle(RadialToggleStyle())
                            .onChange(of: miniFreakEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "EnableMiniFreakEngine")
                            }
                        Spacer()
                        Button {
                            AUEngine.shared.openPluginUI()
                        } label: {
                            Text("Open plugin")
                        }
                        .buttonStyle(BWOutlineButtonStyle(minWidth: 140, height: 32))
                        .disabled(!miniFreakEnabled)
                        .opacity(miniFreakEnabled ? 1 : 0.4)
                    }

                    Text("Loads MiniFreak V in-process. Each heartbeat fires the player's locked pentatonic MIDI note (P1=C2 … P6=C5) on MIDI channel 1. Open the plugin UI to switch to a polyphonic preset (otherwise all players collapse to the last note), load/save presets, and bond the hardware via MIDI input.")
                        .font(Type.sans(11))
                        .foregroundColor(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 24)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Hairline()
                .padding(.vertical, 8)

            // Research settings — full width, flush left. Open-logs button stays on the right of the header row.
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    SectionHeading(title: "Research settings")
                    Spacer()
                    Button {
                        ResearchLogger.shared.openLogsFolder()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 11, weight: .medium))
                            Text("Open logs folder")
                        }
                    }
                    .buttonStyle(BWOutlineButtonStyle(minWidth: 180, height: 32))
                }

                HStack(spacing: 10) {
                    Toggle("Enable Research Logging", isOn: $researchLoggingEnabled)
                        .toggleStyle(RadialToggleStyle())
                        .onChange(of: researchLoggingEnabled) { _, newValue in
                            ResearchLogger.shared.isEnabled = newValue
                        }
                        .disabled(simulationEnabled)

                    if simulationEnabled {
                        Text("(disabled during simulation)")
                            .font(Type.sans(10, weight: .medium))
                            .tracking(1.4)
                            .textCase(.uppercase)
                            .foregroundColor(Palette.muted)
                    }
                }

                Text("Heart rate and synchronization data is logged to CSV files in your iCloud Drive for research analysis.")
                    .font(Type.sans(11))
                    .foregroundColor(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Hairline()
                .padding(.top, 8)

            // Action buttons
            HStack(spacing: 16) {
                Button("Reset all") { showResetAlert = true }
                    .buttonStyle(BWTextLinkButtonStyle())

                Spacer()

                Button("Cancel") { gameStateManager.closeConfiguration() }
                    .buttonStyle(BWOutlineButtonStyle(minWidth: 120, height: 42))

                Button("Save & continue") {
                    configManager.saveConfig()
                    gameStateManager.closeConfiguration()
                }
                .buttonStyle(BWPrimaryButtonStyle(minWidth: 200, height: 42))
                .disabled(!simulationEnabled && configManager.configurationNeeded)
                .opacity((!simulationEnabled && configManager.configurationNeeded) ? 0.4 : 1)
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
            // Surface already-connected straps even if scan can't run yet.
            configManager.refreshConnectedDevices()
            if configManager.bluetoothState == .poweredOn {
                configManager.startScan()
            }
            // Probe each paired monitor to find out which are actually being
            // worn (non-zero BPM) vs just advertising while charging. Drives
            // the dot in the Player Assignments dropdown.
            configManager.startLivenessProbing()
        }
        .onDisappear {
            // Stop probing the moment the user leaves the config screen so
            // the per-player HeartRateManager connections claim the airwaves
            // during gameplay without interference.
            configManager.stopLivenessProbing()
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

    // Derived from the live config so reassignment stays in sync automatically.
    var isPaired: Bool {
        configManager.config.monitors.contains { $0.uuid == device.uuid }
    }
    var isSelected: Bool {
        configManager.config.selectedPlayerUUIDs.contains(device.uuid)
    }
    var statusText: String {
        if isSelected { return "Assigned" }
        if isPaired { return "Paired" }
        return "Available"
    }
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(Type.sans(13, weight: isPaired ? .medium : .regular))
                    .foregroundColor(Palette.ink)
                Text(device.uuid.uuidString)
                    .font(Type.sans(10))
                    .foregroundColor(Palette.muted)
            }

            Spacer()

            // Square monochrome status pill — filled ink for assigned, outlined for paired, faint for available.
            Text(statusText.uppercased())
                .font(Type.sans(9, weight: .medium))
                .tracking(1.4)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundColor(isSelected ? Palette.canvas : Palette.ink)
                .background(isSelected ? Palette.ink : Palette.canvas)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: isSelected ? 0 : 1))

            if isPaired {
                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Palette.ink)
                        .frame(width: 22, height: 22)
                        .background(Palette.canvas)
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Remove device")
            } else {
                Button(action: { configManager.addMonitor(from: device) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Palette.canvas)
                        .frame(width: 22, height: 22)
                        .background(Palette.ink)
                }
                .buttonStyle(.plain)
                .help("Add device")
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Offline Device Row

struct OfflineDeviceRow: View {
    let monitor: MonitorDevice
    @ObservedObject var configManager: ConfigurationManager

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.name)
                    .font(Type.sans(13))
                    .foregroundColor(Palette.ink)
                Text(monitor.uuid.uuidString)
                    .font(Type.sans(10))
                    .foregroundColor(Palette.muted)
            }

            Spacer()

            // Offline = dashed outline, no fill. Same square geometry as other badges.
            Text("OFFLINE")
                .font(Type.sans(9, weight: .medium))
                .tracking(1.4)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundColor(Palette.muted)
                .overlay(
                    Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .foregroundColor(Palette.muted)
                )

            Button(action: { configManager.removeMonitor(uuid: monitor.uuid) }) {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .frame(width: 22, height: 22)
                    .background(Palette.canvas)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .opacity(0.6)
    }
}

// MARK: - Player Slot Picker

struct PlayerSlotPicker: View {
    let playerNumber: Int
    @ObservedObject var configManager: ConfigurationManager

    var body: some View {
        HStack(spacing: 14) {
            // Availability indicator: filled = assigned & live, outline = assigned, hollow = unassigned.
            Circle()
                .stroke(Palette.ink, lineWidth: 1)
                .frame(width: 9, height: 9)
                .overlay(
                    Group {
                        if let uuid = selectedBinding.wrappedValue {
                            Circle()
                                .fill(Palette.ink)
                                .frame(width: 5, height: 5)
                                .opacity(isDeviceAvailable(uuid) ? 1 : 0.4)
                        }
                    }
                )

            Text("Player \(playerNumber)")
                .font(Type.sans(11, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(Palette.ink)
                .frame(width: 70, alignment: .leading)

            Menu {
                Button {
                    updateSelection(nil)
                } label: {
                    Text("Unassigned")
                }
                Divider()
                // The dot is driven by MonitorLivenessProber — a brief GATT
                // probe per monitor that connects, listens for a non-zero BPM
                // notification, then disconnects. Charging straps that just
                // advertise BLE without measuring will *not* get the dot;
                // straps actually being worn will.
                ForEach(availableMonitors, id: \.uuid) { monitor in
                    Button {
                        updateSelection(monitor.uuid)
                    } label: {
                        if configManager.isDeviceLive(monitor.uuid) {
                            Label(monitor.name, systemImage: "circle.fill")
                        } else {
                            Text(monitor.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentLabel)
                        .font(Type.sans(12, weight: hasSelection ? .medium : .regular))
                        .foregroundColor(hasSelection ? Palette.ink : Palette.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Palette.ink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Palette.canvas)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasSelection: Bool { selectedBinding.wrappedValue != nil }

    private var currentLabel: String {
        guard let uuid = selectedBinding.wrappedValue else { return "Select device" }
        if let monitor = configManager.config.monitor(for: uuid) {
            return monitor.name
        }
        return "Select device"
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

// MARK: - Monochrome stepper
// Replaces SwiftUI's native Stepper so the +/− chrome stays pure black/white.

struct MonochromeStepper: View {
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            chromeButton(systemImage: "minus", enabled: value > range.lowerBound) {
                onChange(max(value - 1, range.lowerBound))
            }

            Text("\(value)")
                .font(Type.sans(13, weight: .medium))
                .foregroundColor(Palette.ink)
                .frame(width: 44, height: 30)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))

            chromeButton(systemImage: "plus", enabled: value < range.upperBound) {
                onChange(min(value + 1, range.upperBound))
            }
        }
    }

    private func chromeButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Palette.ink)
                .frame(width: 30, height: 30)
                .background(Palette.canvas)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
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
