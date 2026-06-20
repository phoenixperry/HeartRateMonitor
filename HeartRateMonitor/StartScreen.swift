import SwiftUI

struct StartScreen: View {
    @ObservedObject var gameStateManager: GameStateManager

    @State private var soundDesignerVisible = false

    private var miniFreakEnabled: Bool {
        UserDefaults.standard.bool(forKey: "EnableMiniFreakEngine")
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(spacing: 24) {
                titleBlock
                    .bwFadeIn(delay: 0.05)

                playerGrid
                    .bwFadeIn(delay: 0.2)

                bottomSection
                    .bwFadeIn(delay: 0.35)
            }
            .padding(.horizontal, 48)
            .padding(.top, 48)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $soundDesignerVisible) {
            SoundDesignerScreen()
        }
    }

    // MARK: - Title

    // Header mirrors GameScreen's pattern (left-aligned title + right-aligned
    // status) so the card grid below sits in the same vertical position on
    // both screens — only the framing copy changes, not the layout.
    private var titleBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Setup")
                Text("Resonant Thrum")
                    .font(Type.display(40, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .kerning(-0.5)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Eyebrow(text: "Connected")
                Text("\(gameStateManager.connectedPlayerCount)")
                    .font(Type.display(40, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .kerning(-0.5)
            }
        }
    }

    // MARK: - Players

    private var playerGrid: some View {
        Group {
            if gameStateManager.players.isEmpty {
                emptyState
            } else {
                playerRows
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playerRows: some View {
        let cols = gridColumnCount
        let players = gameStateManager.players
        let rows = stride(from: 0, to: players.count, by: cols).map { startIdx in
            Array(players[startIdx..<min(startIdx + cols, players.count)])
        }
        return VStack(spacing: 20) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: 20) {
                    ForEach(rows[rowIdx]) { player in
                        PlayerCardView(viewModel: player)
                    }
                    if rows[rowIdx].count < cols {
                        ForEach(0..<(cols - rows[rowIdx].count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // Designer-side utilities sit on the left (open the plugin UI, open the
    // sound-designer sheet) so the operator can audition voicings while
    // straps are firing on the cards above. Primary CTA stays on the right.
    private var bottomSection: some View {
        HStack(spacing: 12) {
            Button {
                AUEngine.shared.openPluginUI()
            } label: {
                Text("Open plugin")
            }
            .buttonStyle(BWOutlineButtonStyle(minWidth: 140, height: 36))
            .disabled(!miniFreakEnabled)
            .opacity(miniFreakEnabled ? 1 : 0.35)

            Button {
                soundDesignerVisible = true
            } label: {
                Text("Sound designer")
            }
            .buttonStyle(BWOutlineButtonStyle(minWidth: 160, height: 36))
            .disabled(!miniFreakEnabled)
            .opacity(miniFreakEnabled ? 1 : 0.35)

            Spacer()

            Button("Begin experience") {
                gameStateManager.startGame()
            }
            .buttonStyle(BWPrimaryButtonStyle(minWidth: 260, height: 44))
            .opacity(gameStateManager.currentState == .ready ? 1 : 0)
            .allowsHitTesting(gameStateManager.currentState == .ready)
            .animation(.easeOut(duration: 0.35), value: gameStateManager.currentState)
        }
    }

    // MARK: - Layout

    private var gridColumnCount: Int {
        let count = gameStateManager.players.count
        if count <= 3 { return max(count, 1) }
        if count <= 4 { return 2 }
        return 3
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
