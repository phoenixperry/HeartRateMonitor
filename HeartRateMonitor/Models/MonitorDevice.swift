import Foundation

/// Represents a paired heart rate monitor device stored in configuration
struct MonitorDevice: Codable, Identifiable, Equatable {
    let uuid: UUID
    var name: String
    var lastSeen: Date

    var id: UUID { uuid }

    init(uuid: UUID, name: String, lastSeen: Date = Date()) {
        self.uuid = uuid
        self.name = name
        self.lastSeen = lastSeen
    }
}
