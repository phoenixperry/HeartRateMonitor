import SwiftUI

struct StartScreen: View {
    @ObservedObject var gameStateManager: GameStateManager

    var body: some View {
        VStack(spacing: 40) {
            Text("Resonance")
                .font(.largeTitle)
                .bold()

            // Dynamic player grid layout
            LazyVGrid(columns: gridColumns, spacing: 30) {
                ForEach(gameStateManager.players) { player in
                    PlayerCardView(viewModel: player)
                }
            }

            // Show message if no players configured
            if gameStateManager.players.isEmpty {
                VStack {
                    Text("No players configured")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Open settings to add devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            VStack {
                Text("\(gameStateManager.connectedPlayerCount) player\(gameStateManager.connectedPlayerCount == 1 ? "" : "s") connected. Ready to start.")
                    .font(.caption)
                    .foregroundColor(.green)

                Button("Begin Experience") {
                    gameStateManager.startGame()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .opacity(gameStateManager.currentState == .ready ? 1 : 0)
            .allowsHitTesting(gameStateManager.currentState == .ready)
        }
        .padding()
    }

    // Determine grid columns based on player count
    private var gridColumns: [GridItem] {
        let count = gameStateManager.players.count
        if count <= 3 {
            return Array(repeating: GridItem(.flexible()), count: max(count, 1))
        } else {
            // For 4-6 players, use 2 or 3 columns
            let columnCount = count <= 4 ? 2 : 3
            return Array(repeating: GridItem(.flexible()), count: columnCount)
        }
    }
}

#Preview {
    let configManager = ConfigurationManager()
    let espManager = ESPPeripheralManager()

    return StartScreen(
        gameStateManager: GameStateManager(
            espManager: espManager,
            configManager: configManager
        )
    )
}
