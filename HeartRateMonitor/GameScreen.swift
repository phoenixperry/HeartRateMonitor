// GameScreen.swift
import SwiftUI

struct GameScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemaining: TimeInterval = 0

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            // Reactive-only background — emerges only when the group's
            // synchronization score crosses ~85%, peaks at ~95%.
            SyncHaloBackground(synchronization: gameStateManager.calculateSynchronization())
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                playerGrid

                controls
            }
            .padding(.horizontal, 48)
            .padding(.top, 48)
            .padding(.bottom, 32)
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
        let cols = gridColumnCount
        let players = gameStateManager.players
        let rows = stride(from: 0, to: players.count, by: cols).map { startIdx in
            Array(players[startIdx..<min(startIdx + cols, players.count)])
        }
        return ZStack {
            // Constellation lines emerge between cards at the same threshold
            // as the halo, layered behind the cards themselves.
            SyncConstellationOverlay(
                synchronization: gameStateManager.calculateSynchronization(),
                columns: cols,
                rows: rows.count
            )

            VStack(spacing: 20) {
                ForEach(rows.indices, id: \.self) { rowIdx in
                    HStack(spacing: 20) {
                        ForEach(rows[rowIdx]) { player in
                            PlayerCardView(viewModel: player)
                        }
                        // Pad short last row so card widths stay uniform.
                        if rows[rowIdx].count < cols {
                            ForEach(0..<(cols - rows[rowIdx].count), id: \.self) { _ in
                                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 16) {
            // Operator-only sync tuning: BPM thresholds for entering/leaving
            // a sync group. Session-only — a restart puts the defaults back.
            SyncThresholdControls(engine: gameStateManager.syncEngine)

            Spacer()

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

    private var gridColumnCount: Int {
        let count = gameStateManager.players.count
        if count <= 3 { return max(count, 1) }
        if count <= 4 { return 2 }
        return 3
    }
}

// ─────────────────────────────────────────────────────────────────────────────

// The sync thresholds, live-adjustable mid-round. "Lock ≤" is how close (in
// BPM) a player must be to a group's tempo to join it; "Release ≥" how far
// they must drift to leave. The engine keeps release strictly above lock so
// the band can never collapse to zero and flap. Its own @ObservedObject —
// SyncEngine's @Published changes don't flow through GameStateManager.
struct SyncThresholdControls: View {
    @ObservedObject var engine: SyncEngine

    var body: some View {
        HStack(spacing: 14) {
            Eyebrow(text: "Lock ≤")
            MonochromeStepper(
                value: engine.enterThresholdBPM,
                range: 1...10,
                onChange: { engine.setEnterThreshold($0) }
            )

            Eyebrow(text: "Release ≥")
            MonochromeStepper(
                value: engine.exitThresholdBPM,
                range: 2...15,
                onChange: { engine.setExitThreshold($0) }
            )

            Eyebrow(text: "BPM")
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
            .frame(maxWidth: .infinity)
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
            .frame(maxWidth: .infinity)
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
