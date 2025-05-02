import SwiftUI

struct ContentView: View {
    @ObservedObject var gameStateManager: GameStateManager
    
    var body: some View {
        Group {
            switch gameStateManager.currentState {
            case .setup, .ready:
                StartScreen(gameStateManager: gameStateManager)
            case .playing:
                GameScreen(gameStateManager: gameStateManager)
            case .paused:
                PausedScreen(gameStateManager: gameStateManager)
            case .finished:
                ResultsScreen(gameStateManager: gameStateManager)
            }
        }
    }
}

// Preview provider
#Preview {
    let espManager = ESPPeripheralManager()
    
    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)
    
    let gameStateManager = GameStateManager(
        player1: player1,
        player2: player2,
        player3: player3,
        espManager: espManager
    )
    
    return ContentView(gameStateManager: gameStateManager)
}
