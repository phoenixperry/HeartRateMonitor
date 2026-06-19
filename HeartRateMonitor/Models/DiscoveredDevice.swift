import Foundation
import CoreBluetooth

/// A BLE peripheral the app is currently aware of (runtime only, not persisted).
/// Pairing/assignment state is *not* stored here — derive it from `ConfigurationManager.config`
/// at the point of display so the two never drift out of sync.
struct DiscoveredDevice: Identifiable {
    let peripheral: CBPeripheral
    let uuid: UUID
    let name: String
    var rssi: Int

    var id: UUID { uuid }

    init(peripheral: CBPeripheral, rssi: Int = 0) {
        self.peripheral = peripheral
        self.uuid = peripheral.identifier
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
    }

    init(peripheral: CBPeripheral, name: String, rssi: Int = 0) {
        self.peripheral = peripheral
        self.uuid = peripheral.identifier
        self.name = name
        self.rssi = rssi
    }
}
