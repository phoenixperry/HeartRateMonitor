import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var viewModel: PlayerCardViewModel
    @State private var isConnected = false
    @State public var beats: Int = 70
    @State private var pulse = false

    var body: some View {
        let duration = 60.0 / Double(beats)

        VStack(spacing: 20) {
            Text("Player \(viewModel.id)")
                .font(.title2)

            ZStack{
                Circle()
                    .fill(Color.pink)
                    .frame(width: pulse ? 140 : 100, height: pulse ? 140 : 100)
                    .shadow(radius: 10)
                    .animation(
                        isConnected
                        ? .easeInOut(duration: duration).repeatForever(autoreverses: true)
                        : .default,
                        value: pulse
                    )
                    .onChange(of: isConnected) {
                        if isConnected {
                            pulse = true
                        } else {
                            pulse = false
                        }
                    }
                    .onAppear {
                        if isConnected {
                            pulse = true
                        }
                    }
            }
            .frame(height:140)

            Button(action: {
                isConnected.toggle()
            }) {
                Text(isConnected ? "Disconnect" : "Connect")
                    .padding()
                    .frame(width: 150, height: 50)
            }
        }
        .padding()
    }
}

#Preview {
    PlayerCardView(viewModel: PlayerCardViewModel(id: 1))
}
