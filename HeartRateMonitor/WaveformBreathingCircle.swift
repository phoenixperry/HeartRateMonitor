import SwiftUI

/// Outline circle that breathes in time with a player's BPM.
/// Two concentric strokes — an outer fixed ring and an inner one that scales —
/// give a meditative geometric pulse without any fills or colour.
struct WaveformBreathingCircle: View {

    @Binding var bpm: Int
    @Binding var shouldAnimate: Bool

    var onCycleComplete: (() -> Void)? = nil
    var onScaleUpdate: ((CGFloat) -> Void)? = nil

    // MARK: - Internal animation state

    @State private var currentBPM: Int = 0
    @State private var pendingBPM: Int? = nil
    @State private var lastCycleTime: Date = Date()
    @State private var progress: Double = 0
    @State private var hasTriggeredCycle = false

    // MARK: - Animation config

    private let minScale: CGFloat = 0.78
    private let maxScale: CGFloat = 1.02
    private let strokeWidth: CGFloat = 1.25
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        ZStack {
            // Outer reference ring — static.
            Circle()
                .stroke(Palette.ink, lineWidth: strokeWidth)

            // Inner ring — breathes with the heartbeat when animating.
            if shouldAnimate && bpm > 0 {
                Circle()
                    .stroke(Palette.ink, lineWidth: strokeWidth)
                    .scaleEffect(scale(for: progress))
                    .animation(.easeInOut(duration: 1.0 / 60.0), value: progress)
            } else {
                // At rest: a slightly smaller faint inner ring as a placeholder geometry.
                Circle()
                    .stroke(Palette.line, lineWidth: strokeWidth)
                    .scaleEffect(0.86)
            }
        }
        .onAppear {
            currentBPM = max(bpm, 1)
            lastCycleTime = Date()
        }
        .onReceive(timer) { date in
            if shouldAnimate && bpm > 0 { updateProgress(date) }
        }
        .onChange(of: bpm) { oldBPM, newBPM in
            guard newBPM != oldBPM else { return }
            // Bootstrap case: card was rendered before any BPM arrived, so
            // currentBPM was clamped to 1 → cycleDuration = 60 s, meaning the
            // first cycleCompleted() (which fires our MIDI note) wouldn't fire
            // for a full minute. If currentBPM is still at the placeholder,
            // jump straight to the real BPM and restart the cycle clock.
            if currentBPM <= 1 && newBPM > 1 {
                currentBPM = newBPM
                lastCycleTime = Date()
                progress = 0
                hasTriggeredCycle = false
            } else {
                // Normal case mid-session: defer to end of current cycle so
                // the visual doesn't jump.
                pendingBPM = newBPM
            }
        }
        .onChange(of: progress) { _, _ in
            onScaleUpdate?(scale(for: progress))
        }
    }

    // MARK: - Timing

    private func cycleDuration(for bpm: Int) -> Double {
        bpm > 0 ? 60.0 / Double(bpm) : 1.0
    }

    private func updateProgress(_ date: Date) {
        let elapsed = date.timeIntervalSince(lastCycleTime)
        let duration = cycleDuration(for: currentBPM)
        progress = (elapsed.truncatingRemainder(dividingBy: duration)) / duration

        if progress < 0.05 && !hasTriggeredCycle {
            hasTriggeredCycle = true
            cycleCompleted(at: date)
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
        if shouldAnimate { onCycleComplete?() }
        if let newBPM = pendingBPM {
            currentBPM = max(newBPM, 1)
            pendingBPM = nil
        }
    }
}
