import SwiftUI

struct ContentView: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var showMetalTest = false
    
    var body: some View {
        ZStack {
            // Regular game content
            Group {
                switch gameStateManager.currentState {
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
            
            // Metal test view (shown when triggered)
            if showMetalTest {
                MetalTestView()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding(40)
                    .overlay(
                        Button("Close") {
                            showMetalTest = false
                        }
                        .padding(),
                        alignment: .topTrailing
                    )
                    .zIndex(1)
            }
        }
        .onAppear {
            // Listen for keystroke
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 17 && event.modifierFlags.contains(.command) {
                    // Cmd+T pressed
                    showMetalTest.toggle()
                    return nil
                }
                return event
            }
        }
        // Add a small hint
        .overlay(
            Text("Press ⌘+T for Metal test")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(8),
            alignment: .bottomTrailing
        )
    }
}
