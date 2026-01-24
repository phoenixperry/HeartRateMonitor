import Foundation
import CoreBluetooth

/// Represents a BLE device discovered during scanning (runtime only, not persisted)
struct DiscoveredDevice: Identifiable {
    let peripheral: CBPeripheral
    let uuid: UUID
    let name: String
    var rssi: Int
    var isPaired: Bool      // Exists in config.monitors
    var isSelected: Bool    // Exists in config.selectedPlayerUUIDs

    var id: UUID { uuid }

    init(peripheral: CBPeripheral, rssi: Int = 0, isPaired: Bool = false, isSelected: Bool = false) {
        self.peripheral = peripheral
        self.uuid = peripheral.identifier
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
        self.isPaired = isPaired
        self.isSelected = isSelected
    }

    var statusText: String {
        if isSelected { return "Assigned" }
        if isPaired { return "Paired" }
        return "Available"
    }
}
