import SwiftUI

struct GameScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemaining: TimeInterval = 0
    
    // Projection mapping controls - these should be persisted between sessions
    @State private var visualScale: CGFloat = 1.0
    @State private var offsetX: CGFloat = 0.0
    @State private var offsetY: CGFloat = 0.0
    @State private var showControls: Bool = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Header with sync score and time
            HStack {
                Text("Synchronization: \(Int(gameStateManager.calculateSynchronization()))%")
                    .font(.headline)

                // Recording indicator
                if ResearchLogger.shared.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                }

                Spacer()

                Text(timeString(from: timeRemaining))
                    .font(.headline)
                    .foregroundColor(timeRemaining < 30 ? .red : .primary)
            }
            .background(Color.black)
            .clipped()
            
            // Heart rate displays - dynamic player grid
            LazyVGrid(columns: gridColumns, spacing: 30) {
                ForEach(gameStateManager.players) { player in
                    PlayerCardView(viewModel: player)
                }
            }
            
            // Controls
            HStack {
                Button("Pause") {
                    gameStateManager.pauseGame()
                }
                .buttonStyle(.bordered)
                
                Button("End Experience") {
                    gameStateManager.endGame()
                }
            }
        }
        .onAppear {
            if let startTime = gameStateManager.gameStartTime {
                let elapsed = Date().timeIntervalSince(startTime) - gameStateManager.totalPausedTime
                timeRemaining = gameStateManager.gameDuration - elapsed
                if timeRemaining <= 0 {
                    gameStateManager.endGame()
                }
            } else {
                timeRemaining = gameStateManager.gameDuration
            }
        }
        .onReceive(timer) { _ in
            if let startTime = gameStateManager.gameStartTime {
                let elapsed = Date().timeIntervalSince(startTime) - gameStateManager.totalPausedTime
                timeRemaining = gameStateManager.gameDuration - elapsed
                if timeRemaining <= 0 {
                    gameStateManager.endGame()
                }
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
    let espManager = ESPPeripheralManager()
    
    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Experience Complete")
                .font(.largeTitle)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Synchronization Score: \(Int(gameStateManager.calculateSynchronization()))%")
                    .font(.title3)
                
                if let startTime = gameStateManager.gameStartTime {
                    Text("Duration: \(formattedDuration(from: startTime))")
                        .font(.title3)
                }

                // Research data points
                if ResearchLogger.shared.lastSessionRecordCount > 0 {
                    Text("Data Points Recorded: \(ResearchLogger.shared.lastSessionRecordCount)")
                        .font(.title3)
                }
            }
            .padding()
            .frame(maxWidth: 500)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
            
            Text("Thank you for participating in Resonance")
                .font(.title2)
                .padding(.top)
            
            Button("Start New Experience") {
                gameStateManager.resetGame()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .padding()
    }
    
    return GameScreen(gameStateManager: gameStateManager)
}
