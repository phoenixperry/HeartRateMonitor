import Foundation

/// App configuration stored in JSON file
struct AppConfiguration: Codable {
    var monitors: [MonitorDevice]       // All known/paired devices
    var selectedPlayerUUIDs: [UUID]     // UUIDs assigned to players (ordered by player number)
    var playerCount: Int                // Target player count (2-6)

    static let defaultPlayerCount = 3
    static let minPlayers = 2
    static let maxPlayers = 6

    static var empty: AppConfiguration {
        AppConfiguration(monitors: [], selectedPlayerUUIDs: [], playerCount: defaultPlayerCount)
    }

    /// Validates that playerCount is within allowed range
    var isPlayerCountValid: Bool {
        playerCount >= Self.minPlayers && playerCount <= Self.maxPlayers
    }

    /// Checks if we have enough selected players
    var hasEnoughPlayers: Bool {
        selectedPlayerUUIDs.count >= playerCount
    }

    /// Returns the monitor for a given UUID if it exists
    func monitor(for uuid: UUID) -> MonitorDevice? {
        monitors.first { $0.uuid == uuid }
    }
}
