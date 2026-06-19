import SwiftUI

struct StartScreen: View {
    @ObservedObject var gameStateManager: GameStateManager

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(spacing: 56) {
                titleBlock
                    .bwFadeIn(delay: 0.05)

                playerGrid
                    .bwFadeIn(delay: 0.2)

                Spacer(minLength: 0)

                bottomSection
                    .bwFadeIn(delay: 0.35)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 56)
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 14) {
            Text("Resonant Thrum")
                .font(Type.display(60, weight: .medium))
                .foregroundColor(Palette.ink)
                .kerning(-0.8)
            Hairline().frame(width: 64)
                .padding(.top, 6)
        }
    }

    // MARK: - Players

    private var playerGrid: some View {
        Group {
            if gameStateManager.players.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: gridColumns, spacing: 28) {
                    ForEach(gameStateManager.players) { player in
                        PlayerCardView(viewModel: player)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Circle()
                .stroke(Palette.line, lineWidth: 1)
                .frame(width: 80, height: 80)
            Text("No players configured")
                .font(Type.sans(13, weight: .medium))
                .foregroundColor(Palette.ink)
            Text("Open settings to add devices")
                .font(Type.sans(12))
                .foregroundColor(Palette.muted)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Bottom CTA

    private var bottomSection: some View {
        VStack(spacing: 16) {
            Text("\(gameStateManager.connectedPlayerCount) player\(gameStateManager.connectedPlayerCount == 1 ? "" : "s") connected")
                .font(Type.sans(11, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(Palette.muted)

            Button("Begin experience") {
                gameStateManager.startGame()
            }
            .buttonStyle(BWPrimaryButtonStyle(minWidth: 260, height: 52))
        }
        .opacity(gameStateManager.currentState == .ready ? 1 : 0)
        .allowsHitTesting(gameStateManager.currentState == .ready)
        .animation(.easeOut(duration: 0.35), value: gameStateManager.currentState)
    }

    // MARK: - Layout

    private var gridColumns: [GridItem] {
        let count = gameStateManager.players.count
        if count <= 3 {
            return Array(repeating: GridItem(.flexible(), spacing: 28), count: max(count, 1))
        } else {
            let columnCount = count <= 4 ? 2 : 3
            return Array(repeating: GridItem(.flexible(), spacing: 28), count: columnCount)
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
