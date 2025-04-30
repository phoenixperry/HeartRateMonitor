import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var viewModel: PlayerCardViewModel
    
    // MARK: - Animation State
    // This is the source of truth for animation
    @State private var shouldAnimate = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Player \(viewModel.id)")
                .font(.title2)
            
            // Heart rate visualization
            ZStack {
                if viewModel.isConnected {
                    WaveformBreathingCircle(
                        bpm: $viewModel.heartRate,
                        shouldAnimate: $shouldAnimate
                    ) {
                        viewModel.cycleDidComplete()
                    }
                    .frame(width: 140, height: 140)
                    .overlay(
                        Text("\(viewModel.heartRate) bpm")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Text("Not Connected")
                                .font(.caption)
                                .foregroundColor(.gray)
                        )
                }
            }
            
            // Connection controls
            HStack {
                Button(action: {
                    // Connect and prepare for animation
                    viewModel.connect()
                }) {
                    Text("Connect")
                        .frame(width: 100)
                }
                .disabled(viewModel.isConnected)
                
                Button(action: {
                    // Stop animation and disconnect
                    shouldAnimate = false
                    viewModel.disconnect()
                }) {
                    Text("Disconnect")
                        .frame(width: 100)
                }
                .disabled(!viewModel.isConnected)
            }
            
            Button(action: {
                viewModel.startPlay()
                shouldAnimate = true  // Explicitly start animation
            }) {
                Text(viewModel.hasStartedPlay ? "You're in the group" : "Join the group!")
                    .frame(width: 150, height: 44)
                    .background(viewModel.hasStartedPlay ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isConnected || viewModel.hasStartedPlay)
        }
        .padding()
        .frame(width: 240)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
        .shadow(radius: 5)
        .buttonStyle(.plain)
        // Add reactive updates for connection state changes
        .onChange(of: viewModel.isConnected) { _, isConnected in
            if !isConnected {
                // If disconnected, ensure animation stops
                shouldAnimate = false
            }
        }
        // Add reactive updates for play state changes
        .onChange(of: viewModel.hasStartedPlay) { _, hasStarted in
            // Update animation state based on play state
            shouldAnimate = hasStarted && viewModel.isConnected
        }
    }
}

#Preview {
    PlayerCardView(viewModel: PlayerCardViewModel(
        id: 1,
        deviceUUID: UUID(),
        espManager: ESPPeripheralManager()
    ))
}
