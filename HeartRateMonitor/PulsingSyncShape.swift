import SwiftUI

struct PulsingSyncShape: View {
    let heartRate: Int
    let morphLevel: Double
    let color: Color
    let onCycleComplete: (() -> Void)?
    
    @State private var shouldAnimate = false
    
    var body: some View {
        WaveformBreathingHexagon(
            bpm: .constant(heartRate),
            morphLevel: .constant(CGFloat(morphLevel)),
            shouldAnimate: .constant(shouldAnimate),
            color: color
        ) {
            // Cycle completion callback - could trigger haptic/sound events
            onCycleComplete?()
        }
        .frame(width: 120, height: 120)
        .onAppear {
            shouldAnimate = heartRate > 0
        }
        .onChange(of: heartRate) { _, newRate in
            shouldAnimate = newRate > 0
        }
    }
}
