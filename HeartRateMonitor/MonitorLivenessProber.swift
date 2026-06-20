//
//  MonitorLivenessProber.swift
//  HeartRateMonitor
//
//  Distinguishes "broadcasting BLE" from "actually sending heart rate".
//  A Polar strap on a charger still advertises the heart rate service (UUID
//  180D), so a pure scan can't tell us whether anyone's wearing it. To know
//  for sure we have to connect, subscribe to the BPM notification (2A37) and
//  see if any non-zero values land within a short window.
//
//  Probes only run while the Configuration screen is on screen — start() and
//  stop() are called from ConfigurationManager via onAppear/onDisappear, so
//  during gameplay the prober is dormant and the per-player HeartRateManager
//  connections own the airwaves.
//

import Foundation
import CoreBluetooth

final class MonitorLivenessProber: NSObject, ObservableObject {

    /// UUIDs of monitors that have transmitted a non-zero BPM within the most
    /// recent probe cycle. Bound to the UI via `configManager.isDeviceLive(_:)`.
    @Published private(set) var liveUUIDs: Set<UUID> = []

    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")

    private let perProbeTimeout: TimeInterval = 5.0
    private let refreshInterval: TimeInterval = 12.0

    private var central: CBCentralManager!
    private var inFlight: [UUID: ProbeContext] = [:]
    private var refreshTimer: Timer?
    private var pendingUUIDs: Set<UUID> = []   // monitors waiting for CB to power on
    private var isRunning = false

    private struct ProbeContext {
        let peripheral: CBPeripheral
        var sawNonZero: Bool
        var timeoutWork: DispatchWorkItem?
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public lifecycle

    /// Begin periodically probing the given monitors. Call again with a new set
    /// to retarget; safe to call repeatedly. Pass an empty array to stop.
    func start(monitoringUUIDs uuids: [UUID]) {
        pendingUUIDs = Set(uuids)
        isRunning = true
        // Drop liveness for monitors we no longer care about.
        liveUUIDs = liveUUIDs.intersection(pendingUUIDs)
        kickOffProbes()
        scheduleRefreshTimer()
    }

    /// Stop all probing and cancel in-flight connections. Call when the
    /// Configuration screen disappears so the prober doesn't fight with
    /// per-player connections during gameplay.
    func stop() {
        isRunning = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        for (uuid, _) in inFlight {
            finishProbe(uuid: uuid, isLive: false)
        }
        pendingUUIDs.removeAll()
    }

    // MARK: - Internals

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.kickOffProbes()
        }
    }

    private func kickOffProbes() {
        guard isRunning else { return }
        guard central.state == .poweredOn else { return }   // wait for state update
        for uuid in pendingUUIDs where inFlight[uuid] == nil {
            beginProbe(uuid: uuid)
        }
    }

    private func beginProbe(uuid: UUID) {
        let known = central.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = known.first else {
            // CoreBluetooth doesn't know this device yet — nothing we can do
            // until the user runs a discovery scan that surfaces it.
            return
        }
        peripheral.delegate = self

        var context = ProbeContext(peripheral: peripheral, sawNonZero: false, timeoutWork: nil)
        let timeout = DispatchWorkItem { [weak self] in
            self?.finishProbe(uuid: uuid, isLive: false)
        }
        context.timeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + perProbeTimeout, execute: timeout)
        inFlight[uuid] = context

        central.connect(peripheral, options: nil)
    }

    private func finishProbe(uuid: UUID, isLive: Bool) {
        guard let context = inFlight.removeValue(forKey: uuid) else { return }
        context.timeoutWork?.cancel()

        if isLive {
            if !liveUUIDs.contains(uuid) { liveUUIDs.insert(uuid) }
        } else {
            if liveUUIDs.contains(uuid) { liveUUIDs.remove(uuid) }
        }

        // Always disconnect to free the link for the per-player HeartRateManager
        // to claim later, and to keep our footprint on the radio minimal.
        if context.peripheral.state == .connected || context.peripheral.state == .connecting {
            central.cancelPeripheralConnection(context.peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension MonitorLivenessProber: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { kickOffProbes() }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([heartRateServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finishProbe(uuid: peripheral.identifier, isLive: false)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // If a probe is still mid-flight when the peripheral disconnects, treat
        // it as inconclusive (not live). If we already finished, this is the
        // disconnect we triggered ourselves; nothing to do.
        if inFlight[peripheral.identifier] != nil {
            finishProbe(uuid: peripheral.identifier, isLive: false)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension MonitorLivenessProber: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            finishProbe(uuid: peripheral.identifier, isLive: false); return
        }
        for service in services where service.uuid == heartRateServiceUUID {
            peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let chars = service.characteristics else {
            finishProbe(uuid: peripheral.identifier, isLive: false); return
        }
        for c in chars where c.uuid == heartRateMeasurementUUID {
            peripheral.setNotifyValue(true, for: c)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == heartRateMeasurementUUID,
              let data = characteristic.value, data.count >= 2 else { return }

        // Same BLE 0x2A37 parse as HeartRateManager.
        let flags = data[0]
        var bpm: UInt16 = 0
        if (flags & 0x01) == 0 {
            bpm = UInt16(data[1])
        } else if data.count >= 3 {
            bpm = UInt16(data[1]) | (UInt16(data[2]) << 8)
        }

        if bpm > 0 {
            finishProbe(uuid: peripheral.identifier, isLive: true)
        }
        // BPM = 0 means strap not yet calibrating skin contact — let the
        // per-probe timeout decide.
    }
}
