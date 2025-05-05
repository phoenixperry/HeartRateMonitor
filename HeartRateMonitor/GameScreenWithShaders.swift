//import SwiftUI
//import MetalKit
//
//struct GameScreenWithShaders: View {
//    @ObservedObject var gameStateManager: GameStateManager
//    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
//    @State private var timeRemaining: TimeInterval = 0
//    
//    var body: some View {
//        Group {
//            if gameStateManager.currentState == .finished {
//                ResultsScreenWithShaders(gameStateManager: gameStateManager)
//            } else {
//                VStack(spacing: 20) {
//                    // Header with sync score and time
//                    HStack {
//                        Text("Synchronization: \(Int(gameStateManager.calculateSynchronization()))%")
//                            .font(.headline)
//                        
//                        Spacer()
//                        
//                        Text(timeString(from: timeRemaining))
//                            .font(.headline)
//                            .foregroundColor(timeRemaining < 30 ? .red : .primary)
//                    }
//                    .padding(.horizontal)
//                    
//                    // Metal shader visualization
//                    MetalShaderView(
//                        playerHeartRates: [
//                            gameStateManager.player1.heartRate,
//                            gameStateManager.player2.heartRate,
//                            gameStateManager.player3.heartRate
//                        ],
//                        synchronizationLevel: gameStateManager.calculateSynchronization() / 100.0
//                    )
//                    .frame(maxWidth: .infinity, maxHeight: 400)
//                    .cornerRadius(20)
//                    .padding(.horizontal)
//                    
//                    // Player stats
//                    HStack(spacing: 30) {
//                        PlayerStatView(playerLabel: "Player 1", bpm: gameStateManager.player1.heartRate)
//                        PlayerStatView(playerLabel: "Player 2", bpm: gameStateManager.player2.heartRate)
//                        PlayerStatView(playerLabel: "Player 3", bpm: gameStateManager.player3.heartRate)
//                    }
//                    .padding()
//                    
//                    // Controls
//                    HStack {
//                        Button("Pause") {
//                            gameStateManager.pauseGame()
//                        }
//                        .buttonStyle(.bordered)
//                        
//                        Button("End Experience") {
//                            gameStateManager.endGame()
//                        }
//                        .buttonStyle(.bordered)
//                        .foregroundColor(.red)
//                    }
//                    .padding()
//                }
//                .onAppear {
//                    if let startTime = gameStateManager.gameStartTime {
//                        timeRemaining = gameStateManager.gameDuration - Date().timeIntervalSince(startTime)
//                        if timeRemaining <= 0 {
//                            gameStateManager.endGame()
//                        }
//                    } else {
//                        timeRemaining = gameStateManager.gameDuration
//                    }
//                }
//                .onReceive(timer) { _ in
//                    if let startTime = gameStateManager.gameStartTime {
//                        timeRemaining = gameStateManager.gameDuration - Date().timeIntervalSince(startTime)
//                        if timeRemaining <= 0 {
//                            gameStateManager.endGame()
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    private func timeString(from timeInterval: TimeInterval) -> String {
//        let minutes = Int(timeInterval) / 60
//        let seconds = Int(timeInterval) % 60
//        return String(format: "%02d:%02d", minutes, seconds)
//    }
//}
//
//// Simple view for showing player stats
//struct PlayerStatView: View {
//    let playerLabel: String
//    let bpm: Int
//    
//    var body: some View {
//        VStack {
//            Text(playerLabel)
//                .font(.headline)
//            Text("\(bpm) BPM")
//                .font(.title2)
//                .fontWeight(.bold)
//        }
//        .padding()
//        .frame(width: 120)
//        .background(Color.black.opacity(0.1))
//        .cornerRadius(10)
//    }
//}
//
//// MARK: - Results Screen with Shaders
//struct ResultsScreenWithShaders: View {
//    @ObservedObject var gameStateManager: GameStateManager
//    
//    var body: some View {
//        VStack(spacing: 40) {
//            Text("Experience Complete")
//                .font(.largeTitle)
//                .padding(.bottom)
//            
//            // Add shader visualization to the results screen
//            MetalShaderView(
//                playerHeartRates: [
//                    gameStateManager.player1.heartRate,
//                    gameStateManager.player2.heartRate,
//                    gameStateManager.player3.heartRate
//                ],
//                synchronizationLevel: gameStateManager.calculateSynchronization() / 100.0
//            )
//            .frame(maxWidth: .infinity, maxHeight: 300)
//            .cornerRadius(20)
//            .padding(.horizontal, 40)
//            
//            VStack(alignment: .leading, spacing: 20) {
//                Text("Synchronization Score: \(Int(gameStateManager.calculateSynchronization()))%")
//                    .font(.title3)
//                
//                if let startTime = gameStateManager.gameStartTime {
//                    Text("Duration: \(formattedDuration(from: startTime))")
//                        .font(.title3)
//                }
//                
//                // More stats could go here
//            }
//            .padding()
//            .frame(maxWidth: 500)
//            .background(Color.black.opacity(0.05))
//            .cornerRadius(12)
//            
//            Text("Thank you for participating in Resonance")
//                .font(.title2)
//                .padding(.top)
//            
//            Button("Start New Experience") {
//                gameStateManager.resetGame()
//            }
//            .buttonStyle(.borderedProminent)
//            .padding(.top, 20)
//        }
//        .padding()
//    }
//    
//    private func formattedDuration(from startTime: Date) -> String {
//        let duration = Date().timeIntervalSince(startTime)
//        let minutes = Int(duration) / 60
//        let seconds = Int(duration) % 60
//        return String(format: "%d min %d sec", minutes, seconds)
//    }
//}
//
//// MARK: - Preview Provider
//#Preview {
//    let espManager = ESPPeripheralManager()
//    
//    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
//    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
//    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)
//    
//    let gameStateManager = GameStateManager(
//        player1: player1,
//        player2: player2,
//        player3: player3,
//        espManager: espManager
//    )
//    
//    return GameScreenWithShaders(gameStateManager: gameStateManager)
//}
