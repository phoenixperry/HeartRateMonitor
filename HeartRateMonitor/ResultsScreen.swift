import SwiftUI

struct ResultsScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Experience Complete")
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Synchronization Score: \(Int(gameStateManager.calculateSynchronization()))%")
                    .font(.title3)
                    .foregroundColor(.white)
                
                if let startTime = gameStateManager.gameStartTime {
                    Text("Duration: \(formattedDuration(from: startTime))")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Individual player stats
                VStack(alignment: .leading, spacing: 10) {
                    Text("Final Heart Rates:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 30) {
                        VStack {
                            Text("Player 1")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("\(gameStateManager.player1.heartRate) BPM")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("Player 2")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("\(gameStateManager.player2.heartRate) BPM")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("Player 3")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("\(gameStateManager.player3.heartRate) BPM")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 500)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            Text("Thank you for participating in Resonance")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top)
            
            Button("Start New Experience") {
                gameStateManager.resetGame()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func formattedDuration(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d min %d sec", minutes, seconds)
    }
}

#Preview {
    let espManager = ESPPeripheralManager()
    
    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)
    
    return ResultsScreen(
        gameStateManager: GameStateManager(
            player1: player1,
            player2: player2,
            player3: player3,
            espManager: espManager
        )
    )
}
