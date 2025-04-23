import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var viewModel: PlayerCardViewModel
    @State private var pulse = false
    @State private var currentBPM: Int = 0
    @State private var pendingBPM: Int = 0
    @State private var animationTimer: Timer?
    let now = Date()
    var bpmDuration: Double {
        guard viewModel.heartRate > 0 else { return 1.0 }
        return 60.0 / Double(viewModel.heartRate)
    }
    
    func beatDuration (for bpm:Int) ->TimeInterval {
        guard bpm > 0 else { return 1.0 }
        return 60.0/Double(bpm)
    }
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        pulse = false
    }
    
    func startAnimationLoop(){
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: beatDuration(for: currentBPM), repeats: true) { _ in
            if currentBPM == 0 {
                stopAnimation()
                return
            }
            //animate the circle
            withAnimation(.easeInOut(duration: 0.3)) {
                pulse.toggle()
            }
            
            viewModel.sendOSC(bpm:currentBPM)
        }
    }
    var body: some View {
        VStack(spacing: 20) {
            let seconds = Calendar.current.component(.second, from: now)
                Text("Player \(viewModel.id)")
                .font(.title2)
            Text("Seconds: \(seconds)")
                .font(.caption)
            ZStack{
            // Optional heart rate circle
            if viewModel.hasStartedPlay {
//                Circle()
//                    .fill(Color.pink)
//                    .frame(width: 140, height: 140)
//                    .scaleEffect(pulse ? 1.1 : 0.9)
//                     .overlay(
//                         Text("\(viewModel.heartRate) bpm")
//                             .font(.caption)
//                             .foregroundColor(.white)
//                     )
//                     .shadow(radius: 10)
//                     .scaleEffect(pulse ? 1.1 : 0.9)
//                     .animation(
//                         .easeInOut(duration: bpmDuration).repeatForever(autoreverses: true),
//                         value: pulse
//                     )
//                     .onAppear {
//                         pulse = true
//                     }
                
                WaveformBreathingCircle(bpm: $viewModel.heartRate) {
                             viewModel.sendOSC(bpm: viewModel.heartRate)
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
                        Text(viewModel.isConnected ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
        }
            .onChange(of: viewModel.heartRate) { oldBPM, newBPM in
                if newBPM == 0 {
                    stopAnimation()
                    currentBPM = 0
                    pendingBPM = 0
                } else {
                    pendingBPM = newBPM
                }
            }
          
//            .onChange(of: viewModel.heartRate) {oldBPM, newBPM in
//                if newBPM == 0{
//                    stopAnimation()
//                    currentBPM = 0
//                    pendingBPM = 0
//                }else { pendingBPM = newBPM }
//                pulse.toggle()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                    pulse.toggle()
//                }
//            }
    

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
