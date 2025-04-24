import SwiftUI

struct WaveformBreathingCircle: View {

    @Binding var bpm: Int

    //this is the syntax to give a view the option to pass a function in here as callback. It's optional and if it is not used, it returns nil. From PlayerCardView, you're passing a closure (a function) as the argument to onCycleComplete.That closure gets run once per beat cycle, and that's when you: Send OSC, Send Bluetooth, Trigger a haptic motor

    var onCycleComplete: (() -> Void)? = nil

    @State private var currentBPM: Int = 0
    @State private var pendingBPM: Int? = nil
    @State private var lastCycleTime: Date = Date()
    @State private var lastProgress: Double = 0
    @State private var hasTriggeredCycle = false
    
    private let minScale: CGFloat = 0.8
    private let maxScale: CGFloat = 1.2

    var body: some View {
        let now = TimelineView.date
        let progress = currentCycleProgress(at: now)
        let scale = scale(for: progress)
//        detect full waveform cycle (wraps from ~1 to ~0)
//         Detect full waveform cycle (wraps from ~1 to ~0)
            if progress < 0.05 && !hasTriggeredCycle {
                DispatchQueue.main.async {
                    hasTriggeredCycle = true
                    cycleCompleted(at: now)
                }
            } else if progress > 0.1 {
                DispatchQueue.main.async {
                    hasTriggeredCycle = false
                }
            }
        TimelineView(.animation) { context in
            ZStack {
                Circle()
                    .fill(Color.pink)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 1.0 / 60.0), value: scale)
            }
        }
        .onAppear {
            currentBPM = bpm
            lastCycleTime = Date()
        }
        .onChange(of: bpm) { oldBPM, newBPM in
            if newBPM != oldBPM {
                pendingBPM = newBPM
            }
        }
    }

    private func cycleDuration(for bpm: Int) -> Double {
        bpm > 0 ? 60.0 / Double(bpm) : .infinity
    }

    private func currentCycleProgress(at now: Date) -> Double {
        let elapsed = now.timeIntervalSince(lastCycleTime)
        let duration = cycleDuration(for: currentBPM)
        return duration == .infinity ? 0 : (elapsed.truncatingRemainder(dividingBy: duration)) / duration
    }

    private func scale(for progress: Double) -> CGFloat {
        let angle = 2 * Double.pi * progress - (.pi / 2) // Align to breathing waveform
        let normalized = sin(angle)
        return minScale + (maxScale - minScale) * (CGFloat(normalized) + 1) / 2
    }

    private func cycleCompleted(at now: Date) {
        lastCycleTime = now
        onCycleComplete?()
        if let newBPM = pendingBPM {
            currentBPM = newBPM
            pendingBPM = nil
        }
    }
}

#Preview {
    StatefulPreviewWrapper(60) { bpm in
        VStack(spacing: 20) {
            WaveformBreathingCircle(bpm: bpm) {
                print("🔔 Cycle completed at BPM: \(bpm.wrappedValue)")
            }
            .frame(width: 200, height: 200)

            Slider(value: Binding(
                get: { Double(bpm.wrappedValue) },
                set: { bpm.wrappedValue = Int($0) }
            ), in: 40...140, step: 1) {
                Text("BPM")
            }
            Text("BPM: \(bpm.wrappedValue)")
        }
        .padding()
    }
}
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
