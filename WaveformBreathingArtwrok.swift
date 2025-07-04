import SwiftUI

/// A beautiful breathing artwork that combines your cycle-based animation with artistic gradients
struct WaveformBreathingArtwork: View {
    
    /// The current BPM, passed in from outside the view
    @Binding var bpm: Int
    
    /// The morphing level (0.0 = hexagon, 1.0 = circle)
    @Binding var morphLevel: CGFloat
    
    /// Controls whether animation is active
    @Binding var shouldAnimate: Bool
    
    /// Color scheme for this player
    let playerColor: PlayerArtColor
    
    /// Intensity based on heart rate activity
    let intensity: Double
    
    /// An optional callback that's called at the completion of each waveform cycle
    var onCycleComplete: (() -> Void)? = nil
    
    // MARK: - Internal animation state
    
    /// Holds the BPM currently being used for animation (only updated at end of cycle)
    @State private var currentBPM: Int = 0
    
    /// A new BPM that has been requested but won't take effect until the next cycle
    @State private var pendingBPM: Int? = nil
    
    /// The time when the last cycle started
    @State private var lastCycleTime: Date = Date()
    
    /// Normalized progress within the current cycle (0.0 → 1.0)
    @State private var progress: Double = 0
    
    /// Used to ensure `onCycleComplete` is only triggered once per cycle
    @State private var hasTriggeredCycle = false
    
    // MARK: - Animation Config
    
    /// The smallest and largest scales for the breathing effect
    private let minScale: CGFloat = 0.85
    private let maxScale: CGFloat = 1.15
    
    /// A repeating timer that ticks at 60fps
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    
    // MARK: - View Body
    
    var body: some View {
        // Only animate when shouldAnimate is true
        if shouldAnimate && bpm > 0 {
            TimelineView(.animation) { _ in
                // Calculate the current scale based on waveform phase
                let scale = scale(for: progress)
                
                // The animated artwork
                PlayerArtwork(
                    playerColor: playerColor,
                    intensity: intensity * Double(scale), // Intensity pulses with breathing
                    morphLevel: Double(morphLevel)
                )
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 1.0 / 60.0), value: scale)
            }
            .onAppear {
                // When view appears, sync the initial BPM and cycle start
                currentBPM = max(bpm, 1) // Avoid division by zero
                lastCycleTime = Date()
                print("🎨 Artwork animation started with BPM: \(currentBPM)")
            }
            .onReceive(timer) { date in
                // Only update animation when shouldAnimate is true
                if shouldAnimate {
                    updateProgress(date)
                }
            }
            .onChange(of: bpm) { oldBPM, newBPM in
                // If BPM changes mid-cycle, store it to apply at the end of the cycle
                if newBPM != oldBPM {
                    pendingBPM = newBPM
                }
            }
        } else {
            // Static artwork when not animating
            PlayerArtwork(
                playerColor: playerColor,
                intensity: intensity * 0.3, // Dimmed when inactive
                morphLevel: Double(morphLevel)
            )
        }
    }
    
    // MARK: - Timing + Logic

    /// Converts BPM to duration in seconds for one cycle
    private func cycleDuration(for bpm: Int) -> Double {
        bpm > 0 ? 60.0 / Double(bpm) : 1.0 // Default to 1 second to avoid division by zero
    }

    /// Calculates cycle progress and handles cycle completion logic
    private func updateProgress(_ date: Date) {
        let elapsed = date.timeIntervalSince(lastCycleTime)
        let duration = cycleDuration(for: currentBPM)

        // Normalize progress to a 0.0–1.0 range
        progress = (elapsed.truncatingRemainder(dividingBy: duration)) / duration

        // Trigger cycle completion only once per cycle
        if progress < 0.05 && !hasTriggeredCycle {
            hasTriggeredCycle = true
            cycleCompleted(at: date)
        } else if progress > 0.1 {
            hasTriggeredCycle = false
        }
    }

    /// Converts a progress value (0.0–1.0) to a scale using a sine waveform
    private func scale(for progress: Double) -> CGFloat {
        // Convert to an angle on the unit circle
        let angle = 2 * Double.pi * progress - (.pi / 2)

        // Normalize -1..1 result of sine wave to 0..1
        let normalized = sin(angle)

        // Linearly interpolate between minScale and maxScale
        return minScale + (maxScale - minScale) * (CGFloat(normalized) + 1) / 2
    }

    /// Called once per cycle; triggers callback and applies pending BPM
    private func cycleCompleted(at now: Date) {
        lastCycleTime = now
        
        if shouldAnimate {
            onCycleComplete?()
        }

        if let newBPM = pendingBPM {
            currentBPM = max(newBPM, 1) // Avoid division by zero
            pendingBPM = nil
        }
    }
}

#Preview {
    ZStack {
        GameBackground()
        
        HStack(spacing: 80) {
            WaveformBreathingArtwork(
                bpm: .constant(72),
                morphLevel: .constant(0.0),
                shouldAnimate: .constant(true),
                playerColor: .player1,
                intensity: 0.8
            )
            .frame(width: 180, height: 180)
            
            WaveformBreathingArtwork(
                bpm: .constant(68),
                morphLevel: .constant(0.5),
                shouldAnimate: .constant(true),
                playerColor: .player2,
                intensity: 0.6
            )
            .frame(width: 180, height: 180)
            
            WaveformBreathingArtwork(
                bpm: .constant(75),
                morphLevel: .constant(1.0),
                shouldAnimate: .constant(true),
                playerColor: .player3,
                intensity: 0.9
            )
            .frame(width: 180, height: 180)
        }
    }
    .frame(width: 1000, height: 700)
}
