import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var viewModel: PlayerCardViewModel
    @State private var shouldAnimate = false

    private let circleSize: CGFloat = 168

    var body: some View {
        VStack(spacing: 22) {
            // Eyebrow label
            HStack {
                Eyebrow(text: "Player \(viewModel.id)")
                Spacer()
                if viewModel.isSimulated {
                    Eyebrow(text: "Sim", color: Palette.ink)
                }
            }

            // Breathing circle with BPM number centred inside.
            ZStack {
                WaveformBreathingCircle(
                    bpm: $viewModel.heartRate,
                    shouldAnimate: $shouldAnimate
                ) {
                    viewModel.cycleDidComplete()
                }
                .frame(width: circleSize, height: circleSize)

                bpmReadout
            }
            .frame(width: circleSize, height: circleSize)

            // Connection state line.
            stateLine

            // Action area.
            if !viewModel.isSimulated {
                actions
            }
        }
        .padding(24)
        .frame(width: 240)
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

    private var bpmReadout: some View {
        VStack(spacing: 0) {
            if viewModel.isConnected && viewModel.heartRate > 0 {
                Text("\(viewModel.heartRate)")
                    .font(Type.display(46, weight: .medium))
                    .foregroundColor(Palette.ink)
                Text("bpm")
                    .font(Type.sans(10, weight: .medium))
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundColor(Palette.muted)
            } else {
                Text("—")
                    .font(Type.display(46, weight: .medium))
                    .foregroundColor(Palette.line)
            }
        }
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
