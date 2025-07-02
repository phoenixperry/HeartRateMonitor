import SwiftUI

struct GameScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemaining: TimeInterval = 0
    
    // Projection mapping controls - these should be persisted between sessions
    @State private var visualScale: CGFloat = 1.0
    @State private var offsetX: CGFloat = 0.0
    @State private var offsetY: CGFloat = 0.0
    @State private var showControls: Bool = false
    
    var body: some View {
        ZStack {
            // Main projection area
            GeometryReader { geometry in
                ZStack {
                    // Background - subtle gradient to help with alignment
                    RadialGradient(
                        colors: [Color.black.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: min(geometry.size.width, geometry.size.height) * 0.4
                    )
                    
                    // Three player visualizations arranged in triangle
                    HexagonVisualizationGroup(
                        player1: gameStateManager.player1,
                        player2: gameStateManager.player2,
                        player3: gameStateManager.player3,
                        syncLevel: gameStateManager.calculateSynchronization() / 100.0,
                        canvasSize: geometry.size
                    )
                    .scaleEffect(visualScale)
                    .offset(x: offsetX, y: offsetY)
                }
            }
            .background(Color.black)
            .clipped()
            
            // Overlay UI (only visible when showControls is true)
            if showControls {
                VStack {
                    // Header with game info
                    HStack {
                        Text("Synchronization: \(Int(gameStateManager.calculateSynchronization()))%")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(timeString(from: timeRemaining))
                            .font(.headline)
                            .foregroundColor(timeRemaining < 30 ? .red : .white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    // Projection mapping controls
                    VStack(spacing: 15) {
                        Text("Projection Mapping Controls")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("Scale:")
                                .foregroundColor(.white)
                            Slider(value: $visualScale, in: 0.1...2.0)
                            Text(String(format: "%.2f", visualScale))
                                .foregroundColor(.white)
                                .frame(width: 50)
                        }
                        
                        HStack {
                            Text("X Offset:")
                                .foregroundColor(.white)
                            Slider(value: $offsetX, in: -400...400)
                            Text(String(format: "%.0f", offsetX))
                                .foregroundColor(.white)
                                .frame(width: 50)
                        }
                        
                        HStack {
                            Text("Y Offset:")
                                .foregroundColor(.white)
                            Slider(value: $offsetY, in: -400...400)
                            Text(String(format: "%.0f", offsetY))
                                .foregroundColor(.white)
                                .frame(width: 50)
                        }
                        
                        // Player stats for debugging
                        HStack(spacing: 30) {
                            PlayerDebugInfo(label: "P1", bpm: gameStateManager.player1.heartRate)
                            PlayerDebugInfo(label: "P2", bpm: gameStateManager.player2.heartRate)
                            PlayerDebugInfo(label: "P3", bpm: gameStateManager.player3.heartRate)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .padding()
                    
                    // Game controls
                    HStack {
                        Button("Pause") {
                            gameStateManager.pauseGame()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("End Experience") {
                            gameStateManager.endGame()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        Button("Hide Controls") {
                            showControls = false
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            setupTimer()
        }
        .onReceive(timer) { _ in
            updateTimer()
        }
        // Key press handling for Mac
        .focusable()
        .onKeyPress { keyPress in
            // Press 'C' to toggle controls
            if keyPress.characters == "c" || keyPress.characters == "C" {
                showControls.toggle()
                return .handled
            }
            // Press ESC to hide controls
            if keyPress.key == .escape {
                showControls = false
                return .handled
            }
            return .ignored
        }
        // Click handling (single click to toggle controls)
        .onTapGesture {
            showControls.toggle()
        }
    }
    
    private func setupTimer() {
        if let startTime = gameStateManager.gameStartTime {
            timeRemaining = gameStateManager.gameDuration - Date().timeIntervalSince(startTime)
            if timeRemaining <= 0 {
                gameStateManager.endGame()
            }
        } else {
            timeRemaining = gameStateManager.gameDuration
        }
    }
    
    private func updateTimer() {
        if let startTime = gameStateManager.gameStartTime {
            timeRemaining = gameStateManager.gameDuration - Date().timeIntervalSince(startTime)
            if timeRemaining <= 0 {
                gameStateManager.endGame()
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    let espManager = ESPPeripheralManager()
    
    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)
    
    let gameStateManager = GameStateManager(
        player1: player1,
        player2: player2,
        player3: player3,
        espManager: espManager
    )
    
    return GameScreen(gameStateManager: gameStateManager)
}
