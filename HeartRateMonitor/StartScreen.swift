import SwiftUI

struct StartScreen: View {
    @ObservedObject var player1: PlayerCardViewModel
    @ObservedObject var player2: PlayerCardViewModel
    @ObservedObject var player3: PlayerCardViewModel

    @ObservedObject var espManager: ESPPeripheralManager

    @State private var isReadyToStart = false
    @State private var showSerialPicker = false
    @State private var lastSentBPMs: [Int] = [0, 0, 0]
    @State private var bpmValues: [Int] = [0, 0, 0]

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
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
//        .onChange(of: [player1.heartRate, player2.heartRate, player3.heartRate]) { oldBPMs, newBPMs in
//            if newBPMs != lastSentBPMs {
//                espManager.sendGroupBPMs(newBPMs)
//                lastSentBPMs = newBPMs
//            }
//        }
        .onChange(of: [player1.isConnected, player2.isConnected, player3.isConnected]) { _, _ in
            isReadyToStart = player1.isConnected && player2.isConnected && player3.isConnected
            if isReadyToStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Transition to Game Screen goes here
                }
            }
        }

        Button("Turn on the vibes") {
            // Future: open serial picker or something cool
        }
        .buttonStyle(.plain)
        .padding()
    }
}

#Preview {
    let espManager = ESPPeripheralManager()
    let player1 = PlayerCardViewModel(
        id: 1,
        deviceUUID: UUID(),
        espManager: espManager
    )
    let player2 = PlayerCardViewModel(
        id: 2,
        deviceUUID: UUID(),
        espManager: espManager
    )
    let player3 = PlayerCardViewModel(
        id: 3,
        deviceUUID: UUID(),
        espManager: espManager
    )

    return StartScreen(
        player1: player1,
        player2: player2,
        player3: player3,
        espManager: espManager
    )
}
