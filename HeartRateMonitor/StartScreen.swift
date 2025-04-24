import SwiftUI

struct StartScreen: View {
    @StateObject private var espManager = ESPPeripheralManager()

    @StateObject private var player1: PlayerCardViewModel
    @StateObject private var player2: PlayerCardViewModel
    @StateObject private var player3: PlayerCardViewModel

    @State private var isReadyToStart = false
    @State private var showSerialPicker = false
    @State private var lastSentBPMs: [Int] = [0, 0, 0]
    @State private var bpmValues: [Int] = [0, 0, 0]

    init() {
        // Create a shared ESPPeripheralManager instance
        let espManager = ESPPeripheralManager()

        _espManager = StateObject(wrappedValue: espManager)

        _player1 = StateObject(wrappedValue: PlayerCardViewModel(
            id: 1,
            deviceUUID: UUID(uuidString: "5807F0AB-EC6C-5388-2F63-C1BA528E3950")!,
            espManager: espManager
        ))

        _player2 = StateObject(wrappedValue: PlayerCardViewModel(
            id: 2,
            deviceUUID: UUID(uuidString: "939617A2-BF34-DA9C-A319-13A252EB4684")!,
            espManager: espManager
        ))

        _player3 = StateObject(wrappedValue: PlayerCardViewModel(
            id: 3,
            deviceUUID: UUID(uuidString: "087AC373-A006-D6B6-26D3-4DD97728DAFF")!,
            espManager: espManager
        ))
    }

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
//        .onChange(of: [player1.heartRate, player2.heartRate, player3.heartRate]) { oldBPMs, newBPMs in
//            if newBPMs != lastSentBPMs {
//                espManager.sendGroupBPMs(newBPMs)
//                lastSentBPMs = newBPMs
//            }
//        }
        .onChange(of: [player1.isConnected, player2.isConnected, player3.isConnected]) {
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
    StartScreen()
}

