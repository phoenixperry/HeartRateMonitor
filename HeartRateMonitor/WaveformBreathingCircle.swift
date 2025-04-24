import SwiftUI

struct WaveformBreathingCircle: View {
    @Binding var bpm: Int
    var onCycleComplete: (() -> Void)? = nil

    @State private var currentBPM: Int = 0
    @State private var pendingBPM: Int? = nil
    @State private var lastCycleTime: Date = Date()
    @State private var progress: Double = 0
    @State private var hasTriggeredCycle = false
    @State private var now = Date()

    private let minScale: CGFloat = 0.8
    private let maxScale: CGFloat = 1.2

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.animation) { _ in
            let scale = scale(for: progress)
            Circle()
                .fill(Color.pink)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 1.0 / 60.0), value: scale)
        }
        .onAppear {
            currentBPM = bpm
            lastCycleTime = Date()
        }
        .onReceive(timer) { date in
            updateProgress(date)
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

    private func updateProgress(_ date: Date) {
        now = date
        let elapsed = now.timeIntervalSince(lastCycleTime)
        let duration = cycleDuration(for: currentBPM)
        progress = duration == .infinity ? 0 : (elapsed.truncatingRemainder(dividingBy: duration)) / duration

        if progress < 0.05 && !hasTriggeredCycle {
            hasTriggeredCycle = true
            cycleCompleted(at: now)
        } else if progress > 0.1 {
            hasTriggeredCycle = false
        }
    }

    private func scale(for progress: Double) -> CGFloat {
        let angle = 2 * Double.pi * progress - (.pi / 2)
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
