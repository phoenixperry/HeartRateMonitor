import SwiftUI

struct PausedScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Experience Paused")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text("Take a moment to breathe...")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 20) {
                Button("Resume") {
                    gameStateManager.resumeGame()
                }
                .buttonStyle(.borderedProminent)
                
                Button("End Experience") {
                    gameStateManager.endGame()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding(.top, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    let espManager = ESPPeripheralManager()
    
    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)
    
    return PausedScreen(
        gameStateManager: GameStateManager(
            player1: player1,
            player2: player2,
            player3: player3,
            espManager: espManager
        )
    )
}
