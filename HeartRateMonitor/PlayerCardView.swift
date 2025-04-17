import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var viewModel: PlayerCardViewModel
    @State private var pulse = false
    
    var bpmDuration: Double {
        guard viewModel.heartRate > 0 else { return 1.0 }
        return 60.0 / Double(viewModel.heartRate)
    }
    var body: some View {
        VStack(spacing: 20) {
           
                Text("Player \(viewModel.id)")
                .font(.title2)
            ZStack{
            // Optional heart rate circle
            if viewModel.hasStartedPlay {
                Circle()
                    .fill(Color.pink)
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.1 : 0.9)
                     .overlay(
                         Text("\(viewModel.heartRate) bpm")
                             .font(.caption)
                             .foregroundColor(.white)
                     )
                     .shadow(radius: 10)
                     .scaleEffect(pulse ? 1.1 : 0.9)
                     .animation(
                         .easeInOut(duration: bpmDuration).repeatForever(autoreverses: true),
                         value: pulse
                     )
                     .onAppear {
                         pulse = true
                     }
            } else {
                Circle()
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Text(viewModel.isConnected ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
        }
            .onChange(of: viewModel.heartRate) {
                pulse.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    pulse.toggle()
                }
            }
    

            // Connect / Disconnect
            HStack {
                Button(action: {
                    if !viewModel.isConnected {
                        viewModel.connect()
                    }

                }) {
                    Text("Connect")
                        .frame(width: 100)
                }
                .disabled(viewModel.isConnected)
                
                Button(action: {
                    viewModel.disconnect()
                }) {
                    Text("Disconnect")
                        .frame(width: 100)
                }
                .disabled(!viewModel.isConnected)
                
            }

            Button(action: {
                viewModel.startPlay()
            }) {
                Text(viewModel.hasStartedPlay ? "You're in the group" : "Join the group!")
                    .frame(width: 150, height: 44)
                    .background(viewModel.hasStartedPlay ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
            }
            .buttonStyle(.plain) /// here!
        
            .disabled(!viewModel.isConnected || viewModel.hasStartedPlay)
     
            
        }
        .padding()
        .frame(width: 240)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
        .shadow(radius: 5)
        .buttonStyle(.plain) /// here!
    }
    
}

#Preview {
    PlayerCardView(viewModel: PlayerCardViewModel(
        id: 1,
        deviceUUID: UUID()
    ))
}
