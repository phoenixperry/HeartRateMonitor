//
//  SyncHaloBackground.swift
//
//  Reactive-only background for the GameScreen. Stays invisible while the
//  group's synchronization score is below ~85%; smoothly emerges as a soft
//  radial bloom centered on the canvas as the score climbs toward 95%;
//  fades back out the same way when it drops. The visualization is a
//  reward, not an ambient feature — participants discover it.
//

import SwiftUI

struct SyncHaloBackground: View {
    /// Synchronization score, 0–100. Read each frame from
    /// `gameStateManager.calculateSynchronization()`.
    let synchronization: Double

    // Threshold band. Below `lowerThreshold` the halo is invisible. Above
    // `upperThreshold` it's at full intensity. Between, it smoothsteps.
    // Tune these to taste — narrower band = more dramatic reveal, wider =
    // more gradual.
    private let lowerThreshold: Double = 85.0
    private let upperThreshold: Double = 95.0

    // Peak opacity at the center of the bloom when sync is at upperThreshold
    // or higher. Stay subtle — this should *feel* like presence, not a
    // notification.
    private let peakOpacity: Double = 0.10

    var body: some View {
        GeometryReader { geo in
            let smaller = min(geo.size.width, geo.size.height)
            let radius = smaller * 0.62

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Palette.ink.opacity(peakOpacity), location: 0.0),
                    .init(color: Palette.ink.opacity(peakOpacity * 0.45), location: 0.35),
                    .init(color: Palette.ink.opacity(0), location: 1.0),
                ]),
                center: .center,
                startRadius: 0,
                endRadius: radius
            )
            .opacity(intensity)
            .animation(.easeInOut(duration: 1.6), value: intensity)
        }
        .allowsHitTesting(false)
    }

    /// 0 below `lowerThreshold`, 1 above `upperThreshold`, smoothstep between.
    private var intensity: Double {
        let t = (synchronization - lowerThreshold) / (upperThreshold - lowerThreshold)
        let clamped = max(0, min(1, t))
        return clamped * clamped * (3 - 2 * clamped)
    }
}
