import SwiftUI

struct StartScreen: View {
    @StateObject private var player1 = PlayerCardViewModel(id: 1)
    @StateObject private var player2 = PlayerCardViewModel(id: 2)
    @StateObject private var player3 = PlayerCardViewModel(id: 3)

    @State private var isReadyToStart = false

    var body: some View {
        VStack(spacing: 40) {
            Text("Resonance")
                .font(.largeTitle)
                .bold()

            HStack(spacing: 30) {
                PlayerCardView(viewModel: player1)
                PlayerCardView(viewModel: player2)
                PlayerCardView(viewModel: player3)
            }

            if isReadyToStart {
                Text("All monitors connected. Starting...")
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .onChange(of: [player1.isConnected, player2.isConnected, player3.isConnected]) {
            isReadyToStart = player1.isConnected && player2.isConnected && player3.isConnected

            if isReadyToStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Transition to Game Screen goes here
                }
            }
        }

    }
}
struct StartScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartScreen()
    }
}
