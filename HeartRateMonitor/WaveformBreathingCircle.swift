import SwiftUI

/// A breathing circle view that animates at the speed of a given BPM (beats per minute).
/// Each BPM cycle follows a sine waveform from 0 to 2π.
/// Triggers `onCycleComplete` at the end of each beat cycle.
struct WaveformBreathingCircle: View {
    
    /// The current BPM, passed in from outside the view. Comparable to a bound property in C# (like `DependencyProperty` or a two-way binding in XAML).
    @Binding var bpm: Int
    ///makle sure the animation starts
    @Binding var shouldAnimate: Bool
    /// An optional callback that's called at the completion of each waveform cycle (i.e., each beat).
    var onCycleComplete: (() -> Void)? = nil
    
    // MARK: - Internal animation state
    
    /// Holds the BPM currently being used for animation (only updated at the end of a cycle).
    @State private var currentBPM: Int = 0
    
    /// A new BPM that has been requested but won't take effect until the next cycle completes.
    @State private var pendingBPM: Int? = nil
    
    /// The time when the last cycle started.
    @State private var lastCycleTime: Date = Date()
    
    /// Normalized progress within the current cycle (0.0 → 1.0).
    @State private var progress: Double = 0
    
    /// Used to ensure `onCycleComplete` is only triggered once per cycle.
    @State private var hasTriggeredCycle = false
    /// Current timestamp used for phase updates.
    @State private var now = Date()
    
    // MARK: - Animation Config
    
    /// The smallest and largest circle scales — 0.8 is minimum (inhaled), 1.2 is maximum (exhaled).
    private let minScale: CGFloat = 0.8
    private let maxScale: CGFloat = 1.2
    
    /// A repeating timer that ticks at 60fps (just like Unity's Update but for visuals only).
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    
    // MARK: - View Body
    
    var body: some View {
        if shouldAnimate {
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
            // When the view appears, sync the initial BPM and cycle start
            currentBPM = bpm
            lastCycleTime = Date()
        }
        .onReceive(timer) { date in
            // Advance the animation frame by updating progress
            updateProgress(date)
        }
        .onChange(of: bpm) { oldBPM, newBPM in
            // If BPM changes mid-cycle, store it to apply at the end of the cycle
            if newBPM != oldBPM {
                pendingBPM = newBPM
            }
        }
        }else{
            Circle()
                .fill(Color.gray)
        }
        
}
    // MARK: - Timing + Logic

    /// Converts BPM to duration in seconds for one cycle
    private func cycleDuration(for bpm: Int) -> Double {
        bpm > 0 ? 60.0 / Double(bpm) : .infinity
    }

    /// Calculates cycle progress and handles cycle completion logic
    private func updateProgress(_ date: Date) {
        now = date
        let elapsed = now.timeIntervalSince(lastCycleTime)
        let duration = cycleDuration(for: currentBPM)

        // Normalize progress to a 0.0–1.0 range
        progress = duration == .infinity ? 0 : (elapsed.truncatingRemainder(dividingBy: duration)) / duration

        // Trigger cycle completion only once per cycle
        if progress < 0.05 && !hasTriggeredCycle {
            hasTriggeredCycle = true
            cycleCompleted(at: now)
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
        onCycleComplete?()

        if let newBPM = pendingBPM {
            currentBPM = newBPM
            pendingBPM = nil
        }
    }
}
//#Preview {
//    // SwiftUI preview using a helper to provide @State binding
//    StatefulPreviewWrapper(60) { bpm in
//        VStack(spacing: 20) {
//            WaveformBreathingCircle(bpm: bpm, shouldAnimate:$shouldAnimate) {
//                print("🔔 Cycle completed at BPM: \(bpm.wrappedValue)")
//            }
//            .frame(width: 200, height: 200)
//
//            // BPM slider for testing different tempos
//            Slider(value: Binding(
//                get: { Double(bpm.wrappedValue) },
//                set: { bpm.wrappedValue = Int($0) }
//            ), in: 40...140, step: 1) {
//                Text("BPM")
//            }
//
//            Text("BPM: \(bpm.wrappedValue)")
//        }
//        .padding()
//    }
//}
///// A helper wrapper that allows us to preview @State-bound views like sliders and inputs
//struct StatefulPreviewWrapper<Value, Content: View>: View {
//    @State private var value: Value
//    let content: (Binding<Value>) -> Content
//
//    init(_ initialValue: Value, content: @escaping (Binding<Value>) -> Content) {
//        self._value = State(initialValue: initialValue)
//        self.content = content
//    }
//
//    var body: some View {
//        content($value)
//    }
//}
