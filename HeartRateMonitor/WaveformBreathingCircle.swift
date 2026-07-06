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
    @State private var progress: Double = 0
    @State private var lastTick: Date? = nil

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
            // jump straight to the real BPM.
            if currentBPM <= 1 && newBPM > 1 {
                currentBPM = newBPM
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
        // The phase ACCUMULATES (+= dt/duration) instead of being re-derived
        // from absolute time mod duration each frame. The old derivation
        // teleported the ring to an arbitrary phase whenever currentBPM
        // changed — (elapsed mod newDuration) has no relation to (elapsed mod
        // oldDuration) — which read as a stutter on every BPM shift even
        // though the tempo application itself was deferred. Now the breath is
        // continuous by construction: tempo AND the grid re-sync below happen
        // ONLY at the cycle min, never mid-breath.
        let dt = lastTick.map { date.timeIntervalSince($0) } ?? 0
        lastTick = date
        guard dt > 0, dt < 0.25 else { return }   // first tick / app hiccup

        progress += dt / cycleDuration(for: currentBPM)
        guard progress >= 1 else { return }

        // ---- Cycle min: the only place anything may shift ----
        progress -= floor(progress)
        cycleCompleted(at: date)      // fires the beat + applies pendingBPM

        // Grid pull: same-BPM circles used to lock into sync automatically
        // because phase came from shared absolute time. Keep that property by
        // easing each circle onto that shared grid — close at most half the
        // gap, capped at 5% of a cycle, and only here at the min where the
        // ring sits within ~2% of rest, so the nudge is invisible.
        let d = cycleDuration(for: currentBPM)
        let grid = (date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: d)) / d
        var err = grid - progress
        if err > 0.5 { err -= 1 } else if err < -0.5 { err += 1 }
        // Floor at 0: a backward correction becomes a brief rest at the min,
        // never a wrap-crossing (crossing re-wraps next tick and re-pulls — a
        // flutter loop that read as the circle hanging after a BPM change).
        progress = max(0.0, progress + min(0.05, max(-0.05, err * 0.5)))
    }

    private func scale(for progress: Double) -> CGFloat {
        let angle = 2 * Double.pi * progress - (.pi / 2)
        let normalized = sin(angle)
        return minScale + (maxScale - minScale) * (CGFloat(normalized) + 1) / 2
    }

    private func cycleCompleted(at now: Date) {
        if shouldAnimate { onCycleComplete?() }
        if let newBPM = pendingBPM {
            currentBPM = max(newBPM, 1)
            pendingBPM = nil
        }
    }
}
