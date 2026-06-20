import SwiftUI

@main
struct HeartRateMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Configuration manager handles device discovery and persistence
    // Created ONCE and shared with GameStateManager
    @StateObject private var configManager: ConfigurationManager

    // Game state manager coordinates gameplay
    @StateObject private var gameStateManager: GameStateManager
    
    init() {
        // Create single instances to be shared
        let espMgr = ESPPeripheralManager()
        let configMgr = ConfigurationManager()

        // Initialize game state manager with dynamic player support
        let gameState = GameStateManager(
            espManager: espMgr,
            configManager: configMgr
        )

        // Store as StateObjects - only initialize once, not at declaration
        self._configManager = StateObject(wrappedValue: configMgr)
        self._gameStateManager = StateObject(wrappedValue: gameState)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                gameStateManager: gameStateManager,
                configManager: configManager
            )
        }
        // 1280×800 (16:10 laptop ratio) on first launch; the layout is
        // proportional so the same design fills the window at fullscreen
        // for the install. No min/max — user can drag to any size and the
        // grid + cards adapt down (or up) to whatever they pick.
        .defaultSize(width: 1280, height: 800)
    }
}
