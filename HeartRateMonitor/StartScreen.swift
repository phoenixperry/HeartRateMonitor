import SwiftUI

struct StartScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var showSerialPicker = false
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Resonance")
                .font(.largeTitle)
                .bold()

            HStack(spacing: 30) {
                PlayerCardView(viewModel: gameStateManager.player1)
                PlayerCardView(viewModel: gameStateManager.player2)
                PlayerCardView(viewModel: gameStateManager.player3)
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
//        .sheet(isPresented: $showSerialPicker) {
//            // Your serial picker view here
//        }
        
//        Button("Turn on the vibes") {
//            showSerialPicker = true
//        }
        .buttonStyle(.plain)
        .padding()
    }
}

#Preview {
    let espManager = ESPPeripheralManager()
    
    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)
    
    return StartScreen(
        gameStateManager: GameStateManager(
            player1: player1,
            player2: player2,
            player3: player3,
            espManager: espManager
        )
    )
}
