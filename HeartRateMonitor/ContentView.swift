import SwiftUI

struct ContentView: View {
    @ObservedObject var gameStateManager: GameStateManager

    var body: some View {
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
