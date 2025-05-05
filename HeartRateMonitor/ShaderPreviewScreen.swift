//import SwiftUI
//import MetalKit
//
//// MARK: - Preview Helper
//struct ShaderPreviewScreen: View {
//    // Simulated data for preview
//    @State private var simulatedHeartRates = [75, 65, 85]
//    @State private var simulatedSync = 0.5
//    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
//    @State private var elapsedTime: Double = 180
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Header with sync score and time
//            HStack {
//                Text("Synchronization: \(Int(simulatedSync * 100))%")
//                    .font(.headline)
//                
//                Spacer()
//                
//                Text(timeString(from: elapsedTime))
//                    .font(.headline)
//                    .foregroundColor(elapsedTime < 30 ? .red : .primary)
//            }
//            .padding(.horizontal)
//            
//            // Metal shader visualization
//            MetalShaderView(
//                playerHeartRates: simulatedHeartRates,
//                synchronizationLevel: simulatedSync
//            )
//            .frame(maxWidth: .infinity, maxHeight: 400)
//            .cornerRadius(20)
//            .padding(.horizontal)
//            
//            // Player stats
//            HStack(spacing: 30) {
//                PlayerStatView(playerLabel: "Player 1", bpm: simulatedHeartRates[0])
//                PlayerStatView(playerLabel: "Player 2", bpm: simulatedHeartRates[1])
//                PlayerStatView(playerLabel: "Player 3", bpm: simulatedHeartRates[2])
//            }
//            .padding()
//            
//            // Simulation controls
//            VStack(spacing: 10) {
//                Text("Simulation Controls")
//                    .font(.headline)
//                
//                HStack {
//                    Text("Synchronization:")
//                    Slider(value: $simulatedSync, in: 0...1)
//                }
//                .padding(.horizontal)
//                
//                HStack {
//                    ForEach(0..<3) { i in
//                        VStack {
//                            Text("P\(i+1):")
//                            Slider(value: Binding(
//                                get: { Double(simulatedHeartRates[i]) },
//                                set: { simulatedHeartRates[i] = Int($0) }
//                            ), in: 50...120, step: 1)
//                        }
//                    }
//                }
//                .padding(.horizontal)
//            }
//            .padding()
//            .background(Color.black.opacity(0.05))
//            .cornerRadius(12)
//        }
//        .padding()
//        .onReceive(timer) { _ in
//            // Simulate slight random variations in heart rates
//            for i in 0..<3 {
//                if Int.random(in: 0...3) == 0 { // 25% chance to change
//                    simulatedHeartRates[i] += Int.random(in: -2...2)
//                    // Keep within reasonable bounds
//                    simulatedHeartRates[i] = max(50, min(120, simulatedHeartRates[i]))
//                }
//            }
//            
//            // Occasionally change sync level
//            if Int.random(in: 0...10) == 0 { // 10% chance to change
//                simulatedSync += Double.random(in: -0.05...0.05)
//                // Keep within bounds
//                simulatedSync = max(0.1, min(0.95, simulatedSync))
//            }
//            
//            // Count down timer
//            elapsedTime -= 0.5
//            if elapsedTime <= 0 {
//                elapsedTime = 180 // Reset timer
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
//// MARK: - Preview Provider
//#Preview {
//    ShaderPreviewScreen()
//}
