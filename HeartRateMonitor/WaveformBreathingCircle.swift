import SwiftUI

/// A breathing circle view that animates at the speed of a given BPM (beats per minute).
/// Each BPM cycle follows a sine waveform from 0 to 2π.
/// Triggers `onCycleComplete` at the end of each beat cycle.
struct WaveformBreathingCircle: View {
    
    /// The current BPM, passed in from outside the view
    @Binding var bpm: Int
    
    /// Controls whether animation is active
    @Binding var shouldAnimate: Bool
    
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
    
    /// The smallest and largest circle scales
    private let minScale: CGFloat = 0.8
    private let maxScale: CGFloat = 1.2
    
    /// A repeating timer that ticks at 60fps
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    
    // MARK: - View Body
    
    var body: some View {
        // Only animate when shouldAnimate is true
        if shouldAnimate && bpm > 0 {
            TimelineView(.animation) { _ in
                // Calculate the current scale based on waveform phase
                let scale = scale(for: progress)
                
                // The animated circle
                Circle()
                    .fill(Color.pink)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 1.0 / 60.0), value: scale)
            }
            .onAppear {
                // When view appears, sync the initial BPM and cycle start
                currentBPM = max(bpm, 1) // Avoid division by zero
                lastCycleTime = Date()
                print("🔴 Animation started with BPM: \(currentBPM)")
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
            // Static circle when not animating
            Circle()
                .fill(bpm > 0 ? Color.pink.opacity(0.5) : Color.gray)
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

    /// Converts a progress value (0.0–1.0) to a circle scale using a cosine waveform
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
