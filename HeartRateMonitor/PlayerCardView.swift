import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var viewModel: PlayerCardViewModel
    @State private var shouldAnimate = false

    var body: some View {
        VStack(spacing: 14) {
            // Eyebrow label
            HStack {
                Eyebrow(text: "Player \(viewModel.id)")
                Spacer()
                if viewModel.isSimulated {
                    Eyebrow(text: "Sim", color: Palette.ink)
                }
            }

            // Breathing circle with BPM number centred inside. Aspect-ratio
            // locked to a square; the surrounding flex frame lets it grow or
            // shrink with whatever cell the grid hands us, so 6 cards fit at
            // 1280×800 and scale up cleanly when the window is enlarged. The
            // GeometryReader reads the cell size and feeds it to the readout
            // so the BPM number scales with the circle instead of staying
            // pinned at 46pt.
            ZStack {
                WaveformBreathingCircle(
                    bpm: $viewModel.heartRate,
                    shouldAnimate: $shouldAnimate
                ) {
                    viewModel.cycleDidComplete()
                }
                .aspectRatio(1, contentMode: .fit)

                GeometryReader { geo in
                    bpmReadout(circleSize: min(geo.size.width, geo.size.height))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Connection state line.
            stateLine

            // Action area.
            if !viewModel.isSimulated {
                actions
            }
        }
        .padding(18)
        // Cards keep a near-square ratio so the breathing circle inside stays
        // big regardless of whether the grid cell is wide-short or
        // tall-narrow. Without this the card stretches to fill its cell and
        // the aspectRatio-fit circle collapses to the cell's short side.
        // 0.95 is "slightly taller than wide" — matches the look from the
        // original 240×~260 card design.
        .aspectRatio(0.95, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas)
        .bwOutline(1)
        .onAppear {
            shouldAnimate = viewModel.hasStartedPlay && viewModel.isConnected
        }
        .onChange(of: viewModel.isConnected) { _, isConnected in
            shouldAnimate = isConnected ? viewModel.hasStartedPlay : false
        }
        .onChange(of: viewModel.hasStartedPlay) { _, hasStarted in
            shouldAnimate = hasStarted && viewModel.isConnected
        }
    }

    // MARK: - Pieces

    /// Renders the BPM number and "bpm" label sized proportionally to the
    /// breathing circle. Ratios (≈0.27 for the number, ≈0.06 for the label)
    /// match the original 46pt / 10pt against the original 168pt circle, so
    /// the visual weight at the default window size is unchanged — but the
    /// readout now grows when the window is fullscreened or shrinks as the
    /// user drags the window smaller.
    private func bpmReadout(circleSize: CGFloat) -> some View {
        let bpmFont = max(circleSize * 0.27, 14)
        let labelFont = max(circleSize * 0.06, 8)
        return VStack(spacing: 0) {
            if viewModel.isConnected && viewModel.heartRate > 0 {
                Text("\(viewModel.heartRate)")
                    .font(Type.display(bpmFont, weight: .medium))
                    .foregroundColor(Palette.ink)
                Text("bpm")
                    .font(Type.sans(labelFont, weight: .medium))
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundColor(Palette.muted)
            } else {
                Text("—")
                    .font(Type.display(bpmFont, weight: .medium))
                    .foregroundColor(Palette.line)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stateLine: some View {
        Text(stateText)
            .font(Type.sans(10, weight: .medium))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundColor(stateColor)
    }

    private var stateText: String {
        if viewModel.isSimulated { return "Simulated stream" }
        if viewModel.hasStartedPlay { return "In group" }
        if viewModel.isConnected { return "Connected" }
        return "Not connected"
    }

    private var stateColor: Color {
        viewModel.isConnected ? Palette.ink : Palette.muted
    }

    private var actions: some View {
        VStack(spacing: 14) {
            // Primary: Join the group
            Button {
                viewModel.startPlay()
                shouldAnimate = true
            } label: {
                Text(viewModel.hasStartedPlay ? "You're in" : "Join the group")
            }
            .buttonStyle(BWPrimaryButtonStyle(minWidth: 170, height: 44))
            .disabled(!viewModel.isConnected || viewModel.hasStartedPlay)
            .opacity((!viewModel.isConnected || viewModel.hasStartedPlay) ? 0.4 : 1)

            // Secondary text controls for connection state.
            HStack(spacing: 14) {
                Button { viewModel.connect() } label: {
                    Text("Connect")
                }
                .buttonStyle(BWTextLinkButtonStyle())
                .disabled(viewModel.isConnected)
                .opacity(viewModel.isConnected ? 0.3 : 1)

                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 1, height: 10)

                Button {
                    shouldAnimate = false
                    viewModel.disconnect()
                } label: {
                    Text("Disconnect")
                }
                .buttonStyle(BWTextLinkButtonStyle())
                .disabled(!viewModel.isConnected)
                .opacity(!viewModel.isConnected ? 0.3 : 1)
            }
        }
    }
}

#Preview {
    PlayerCardView(viewModel: PlayerCardViewModel(
        id: 1,
        deviceUUID: UUID(),
        espManager: ESPPeripheralManager()
    ))
    .padding(40)
    .background(Palette.canvas)
}
