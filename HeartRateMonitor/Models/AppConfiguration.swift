import Foundation

/// App configuration stored in JSON file
struct AppConfiguration: Codable {
    var monitors: [MonitorDevice]       // All known/paired devices
    var selectedPlayerUUIDs: [UUID]     // UUIDs assigned to players (ordered by player number)
    var playerCount: Int                // Target player count (2-6)
    // Session length in seconds, set on the Configuration screen. Optional so
    // config.json files written before this field existed still decode.
    var gameDurationSeconds: Int? = nil

    // MARK: - Tile routing
    // The six hardware tiles (motor + light channels 1-6) are wired to the
    // circuit board in a fixed plug order. The operator labels them A-F and
    // decides which player drives which tile. Two knobs, both optional so
    // older config.json files still decode:
    //
    //   tileAnchor  — rotates the A-F lettering over the fixed channel ring.
    //                 Letter A sits on channel (tileAnchor + 1); the rest
    //                 follow in order, wrapping. This is "start the lettering
    //                 with any tile" — set it once so the on-screen letters
    //                 match how the board sits in the room.
    //   playerTiles — per player slot (by index), the tile LETTER index (0=A …
    //                 5=F) that player stands on / drives. Storing the letter
    //                 (not the channel) means re-anchoring the whole board
    //                 re-routes everyone at once without redoing assignments.
    var tileAnchor: Int? = nil
    var playerTiles: [Int]? = nil

    static let defaultPlayerCount = 3
    static let minPlayers = 2
    static let maxPlayers = 6
    static let defaultGameDurationSeconds = 180
    static let tileLetters = ["A", "B", "C", "D", "E", "F"]

    /// The game timer the play screen counts down.
    var effectiveGameDuration: TimeInterval {
        TimeInterval(gameDurationSeconds ?? Self.defaultGameDurationSeconds)
    }

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

    // MARK: - Tile routing helpers

    /// The lettering rotation, normalised to 0-5. nil defaults to 0 (A on
    /// channel 1), which reproduces the pre-feature behaviour.
    var effectiveTileAnchor: Int {
        (((tileAnchor ?? 0) % 6) + 6) % 6
    }

    /// The tile LETTER index (0=A … 5=F) assigned to a player slot. Defaults
    /// to the identity (player 1 → A, player 2 → B, …) when unset.
    func tileLetterIndex(forPlayerIndex i: Int) -> Int {
        if let tiles = playerTiles, i >= 0, i < tiles.count {
            return ((tiles[i] % 6) + 6) % 6
        }
        return ((i % 6) + 6) % 6
    }

    /// The hardware channel (1-6) a given tile letter maps to, honouring the
    /// anchor. Letter A (0) → channel (anchor + 1), wrapping round the ring.
    func channel(forLetterIndex li: Int) -> Int {
        (((li + effectiveTileAnchor) % 6) + 6) % 6 + 1
    }

    /// The hardware channel (1-6) a given player slot drives.
    func channel(forPlayerIndex i: Int) -> Int {
        channel(forLetterIndex: tileLetterIndex(forPlayerIndex: i))
    }
}
