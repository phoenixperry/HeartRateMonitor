import SwiftUI

struct PulsingSyncShape: View {
    let heartRate: Int
    let morphLevel: Double
    let playerColor: PlayerArtColor
    let onCycleComplete: (() -> Void)?
    
    @State private var shouldAnimate = false
    
    // Calculate intensity based on heart rate activity
    private var intensity: Double {
        heartRate > 0 ? min(1.0, Double(heartRate) / 100.0) : 0.3
    }
    
    // Calculate size based on sync level - closer to sync = larger circles
    private var syncScale: CGFloat {
        let baseScale: CGFloat = 1.0
        let maxSyncScale: CGFloat = 2.0 // Doubles in size when fully synced
        return baseScale + (CGFloat(morphLevel) * (maxSyncScale - baseScale))
    }
    
    var body: some View {
        WaveformBreathingArtwork(
            bpm: .constant(heartRate),
            morphLevel: .constant(CGFloat(morphLevel)), // This drives hexagon→circle morphing
            shouldAnimate: .constant(shouldAnimate),
            playerColor: playerColor,
            intensity: intensity
        ) {
            // Cycle completion callback - could trigger haptic/sound events
            onCycleComplete?()
        }
        .frame(width: 180, height: 180) // Base size
        .scaleEffect(syncScale) // Additional scaling based on sync level
        .onAppear {
            shouldAnimate = heartRate > 0
        }
        .onChange(of: heartRate) { _, newRate in
            shouldAnimate = newRate > 0
        }
    }
}
