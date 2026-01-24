import SwiftUI

@main
struct HeartRateMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Shared ESP manager for haptic feedback
    let espManager = ESPPeripheralManager()

    // Configuration manager handles device discovery and persistence
    @StateObject private var configManager = ConfigurationManager()

    // Game state manager coordinates gameplay
    @StateObject private var gameStateManager: GameStateManager

    init() {
        let espMgr = ESPPeripheralManager()
        let configMgr = ConfigurationManager()

        // Initialize game state manager with dynamic player support
        let gameState = GameStateManager(
            espManager: espMgr,
            configManager: configMgr
        )

        // Store as StateObjects
        self._configManager = StateObject(wrappedValue: configMgr)
        self._gameStateManager = StateObject(wrappedValue: gameState)

        // Note: espManager property is separate instance for backward compat
        // The one passed to GameStateManager is the one that matters
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                gameStateManager: gameStateManager,
                configManager: configManager
            )
        }
    }
}
