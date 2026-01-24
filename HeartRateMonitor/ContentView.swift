import SwiftUI

struct ContentView: View {
    @ObservedObject var gameStateManager: GameStateManager
    @ObservedObject var configManager: ConfigurationManager

    var body: some View {
        Group {
            switch gameStateManager.currentState {
            case .configuring:
                ConfigurationScreen(
                    configManager: configManager,
                    gameStateManager: gameStateManager
                )
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { gameStateManager.openConfiguration() }) {
                    Image(systemName: "gear")
                }
                .help("Device Configuration")
                .disabled(gameStateManager.currentState == .playing || gameStateManager.currentState == .paused)
            }
        }
        .onAppear {
            // Auto-open configuration if needed
            if configManager.configurationNeeded {
                gameStateManager.currentState = .configuring
            }
        }
    }
}
