// GameScreen.swift
import SwiftUI

struct GameScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemaining: TimeInterval = 0

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(spacing: 36) {
                header

                Hairline()

                playerGrid

                Spacer(minLength: 0)

                controls
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
        }
        .onAppear { recalcRemaining() }
        .onReceive(timer) { _ in recalcRemaining() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Synchronisation")
                Text("\(Int(gameStateManager.calculateSynchronization()))%")
                    .font(Type.display(40, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .kerning(-0.5)
            }

            if ResearchLogger.shared.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Palette.ink).frame(width: 6, height: 6)
                    Text("Rec")
                        .font(Type.sans(10, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(Palette.ink)
                .bwOutline(1)
                .offset(y: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Eyebrow(text: "Remaining")
                Text(timeString(from: timeRemaining))
                    .font(Type.display(40, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .kerning(-0.5)
                    .opacity(timeRemaining < 30 ? 0.65 : 1)
            }
        }
    }

    // MARK: - Player grid

    private var playerGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 28) {
            ForEach(gameStateManager.players) { player in
                PlayerCardView(viewModel: player)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 16) {
            Button("Pause")        { gameStateManager.pauseGame() }
                .buttonStyle(BWOutlineButtonStyle(minWidth: 160, height: 44))

            Button("End experience") { gameStateManager.endGame() }
                .buttonStyle(BWPrimaryButtonStyle(minWidth: 220, height: 44))
        }
    }

    // MARK: - Helpers

    private func recalcRemaining() {
        if let startTime = gameStateManager.gameStartTime {
            let elapsed = Date().timeIntervalSince(startTime) - gameStateManager.totalPausedTime
            timeRemaining = gameStateManager.gameDuration - elapsed
            if timeRemaining <= 0 { gameStateManager.endGame() }
        } else {
            timeRemaining = gameStateManager.gameDuration
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

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

// ─────────────────────────────────────────────────────────────────────────────

struct PausedScreen: View {
    @ObservedObject var gameStateManager: GameStateManager

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Concentric outline circles as a meditative paused signal.
                ZStack {
                    Circle()
                        .stroke(Palette.line, lineWidth: 1)
                        .frame(width: 220, height: 220)
                    Circle()
                        .stroke(Palette.ink, lineWidth: 1)
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(Palette.ink)
                        .frame(width: 12, height: 12)
                }

                VStack(spacing: 10) {
                    Eyebrow(text: "Paused")
                    Text("Take a moment to breathe")
                        .font(Type.display(34, weight: .medium))
                        .foregroundColor(Palette.ink)
                        .kerning(-0.4)
                }
                .padding(.top, 10)

                Spacer()

                HStack(spacing: 16) {
                    Button("End experience") { gameStateManager.endGame() }
                        .buttonStyle(BWOutlineButtonStyle(minWidth: 180, height: 46))

                    Button("Resume") { gameStateManager.resumeGame() }
                        .buttonStyle(BWPrimaryButtonStyle(minWidth: 220, height: 46))
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 48)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────

struct ResultsScreen: View {
    @ObservedObject var gameStateManager: GameStateManager

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 14) {
                    Eyebrow(text: "Complete")
                    Text("Experience complete")
                        .font(Type.display(40, weight: .medium))
                        .foregroundColor(Palette.ink)
                        .kerning(-0.5)
                    Hairline().frame(width: 56)
                        .padding(.top, 8)
                }

                statBlock
                    .padding(.top, 8)

                Text("Thank you for participating in Resonant Thrum")
                    .font(Type.sans(13))
                    .foregroundColor(Palette.muted)
                    .padding(.top, 4)

                Spacer()

                Button("Start new experience") {
                    gameStateManager.resetGame()
                }
                .buttonStyle(BWPrimaryButtonStyle(minWidth: 280, height: 50))
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 48)
        }
    }

    private var statBlock: some View {
        VStack(spacing: 18) {
            statRow(label: "Sync score", value: "\(Int(gameStateManager.calculateSynchronization()))%")
            Hairline().frame(maxWidth: 360)
            if let startTime = gameStateManager.gameStartTime {
                statRow(label: "Duration", value: formattedDuration(from: startTime))
                Hairline().frame(maxWidth: 360)
            }
            if ResearchLogger.shared.lastSessionRecordCount > 0 {
                statRow(label: "Data points", value: "\(ResearchLogger.shared.lastSessionRecordCount)")
            }
        }
        .frame(maxWidth: 360)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Type.sans(11, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(Palette.muted)
            Spacer()
            Text(value)
                .font(Type.display(22, weight: .medium))
                .foregroundColor(Palette.ink)
        }
    }

    private func formattedDuration(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }
}
