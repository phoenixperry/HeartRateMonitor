import SwiftUI

@main
struct HeartRateMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Declare shared ESP manager
    let espManager = ESPPeripheralManager()
    
    // Create StateObject for game state manager
    @StateObject private var gameStateManager: GameStateManager
    
    // Create player view models
    private let player1: PlayerCardViewModel
    private let player2: PlayerCardViewModel
    private let player3: PlayerCardViewModel

    init() {
        // Initialize players with the shared ESP manager
        player1 = PlayerCardViewModel(
            id: 1,
            deviceUUID: UUID(uuidString: "5C597A63-FA35-7537-56F5-254229B48FF3")!,
            espManager: espManager
        )

        player2 = PlayerCardViewModel(
            id: 2,
            deviceUUID: UUID(uuidString: "939617A2-BF34-DA9C-A319-13A252EB4684")!,
            espManager: espManager
        )

        player3 = PlayerCardViewModel(
            id: 3,
            deviceUUID: UUID(uuidString: "5807F0AB-EC6C-5388-2F63-C1BA528E3950")!,
            espManager: espManager
        )
        
        // Initialize the game state manager
        let gameState = GameStateManager(
            player1: player1,
            player2: player2,
            player3: player3,
            espManager: espManager
        )
        
        // Use standard StateObject initialization
        self._gameStateManager = StateObject(wrappedValue: gameState)

        // Assign espManager to AppDelegate for cleanup
        appDelegate.espManager = espManager
    }

    var body: some Scene {
        WindowGroup {
            ContentView(gameStateManager: gameStateManager)
        }
    }
}
