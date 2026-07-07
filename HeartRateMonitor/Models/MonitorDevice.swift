import Foundation

/// Represents a paired heart rate monitor device stored in configuration
struct MonitorDevice: Codable, Identifiable, Equatable {
    let uuid: UUID
    var name: String
    var lastSeen: Date
    /// Operator-assigned sticker letter ("A", "B", …) matching the physical
    /// label on the strap. Optional so old config.json files still decode.
    var label: String?

    var id: UUID { uuid }

    /// What the UI shows: "A · Polar H10 12345678" when lettered, else the raw name.
    var displayName: String {
        if let label, !label.isEmpty { return "\(label) · \(name)" }
        return name
    }

    init(uuid: UUID, name: String, lastSeen: Date = Date(), label: String? = nil) {
        self.uuid = uuid
        self.name = name
        self.lastSeen = lastSeen
        self.label = label
    }
}
