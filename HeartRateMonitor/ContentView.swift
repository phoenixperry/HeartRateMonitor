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
        // Force light mode app-wide so the window titlebar / traffic-lights area
        // renders white across all screens (matches the configuration screen).
        // Our content already uses explicit Palette colors so nothing else shifts.
        .preferredColorScheme(.light)
        // Suppress the window title text — the app already brands itself inside.
        .navigationTitle("")
        .onAppear {
            // Auto-open configuration if needed
            if configManager.configurationNeeded {
                gameStateManager.currentState = .configuring
            }
        }
    }
}
