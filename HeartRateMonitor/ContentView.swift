import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var gameStateManager: GameStateManager
    @ObservedObject var configManager: ConfigurationManager

    var body: some View {
        Group {
            switch gameStateManager.currentState {
            case .configuring:
                ConfigurationScreen(
                    configManager: configManager,
                    gameStateManager: gameStateManager
                )
            case .setup, .ready:
                StartScreen(gameStateManager: gameStateManager)
            case .playing:
                GameScreen(gameStateManager: gameStateManager)
            case .paused:
                PausedScreen(gameStateManager: gameStateManager)
            case .finished:
                ResultsScreen(gameStateManager: gameStateManager)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { gameStateManager.openConfiguration() }) {
                    Image(systemName: "gear")
                }
                .help("Device Configuration")
                .disabled(gameStateManager.currentState == .playing || gameStateManager.currentState == .paused)
            }
        }
        // Force light mode app-wide so the window titlebar / traffic-lights area
        // renders white across all screens (matches the configuration screen).
        // Our content already uses explicit Palette colors so nothing else shifts.
        .preferredColorScheme(.light)
        // Suppress the window title text — the app already brands itself inside.
        .navigationTitle("")
        .onAppear {
            // Auto-open configuration if needed
            if configManager.configurationNeeded {
                gameStateManager.currentState = .configuring
            }
            // Clamp the window to fit the visible screen. SwiftUI restores
            // whatever window size the user had last session, which can be
            // larger than the current display (e.g. moved from a big external
            // monitor back to a laptop screen) — that causes content to fall
            // off the right/bottom edges. We resize-to-fit and reposition so
            // the whole window sits inside `visibleFrame` (which excludes the
            // menu bar and Dock).
            DispatchQueue.main.async { Self.clampMainWindowToScreen() }
        }
    }

    private static func clampMainWindowToScreen() {
        guard let window = NSApp.windows.first(where: { $0.isVisible }),
              let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        var changed = false

        if frame.width > visible.width {
            frame.size.width = visible.width
            changed = true
        }
        if frame.height > visible.height {
            frame.size.height = visible.height
            changed = true
        }
        if frame.maxX > visible.maxX {
            frame.origin.x = visible.maxX - frame.width
            changed = true
        }
        if frame.minX < visible.minX {
            frame.origin.x = visible.minX
            changed = true
        }
        if frame.maxY > visible.maxY {
            frame.origin.y = visible.maxY - frame.height
            changed = true
        }
        if frame.minY < visible.minY {
            frame.origin.y = visible.minY
            changed = true
        }
        if changed {
            window.setFrame(frame, display: true)
        }
    }
}
