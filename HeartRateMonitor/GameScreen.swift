// GameScreen.swift
import SwiftUI

struct GameScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemaining: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 40) {
            // Header with sync score and time
            HStack {
                Text("Synchronization: \(Int(gameStateManager.calculateSynchronization()))%")
                    .font(.headline)
                
                Spacer()
                
                Text(timeString(from: timeRemaining))
                    .font(.headline)
                    .foregroundColor(timeRemaining < 30 ? .red : .primary)
            }
            .padding()
            
            // Heart rate displays
            HStack(spacing: 30) {
                VStack {
                    WaveformBreathingCircle(
                        bpm: .constant(gameStateManager.player1.heartRate),
                        shouldAnimate: .constant(true)
                    ) {
                        // Cycle complete
                    }
                    .frame(width: 140, height: 140)
                    
                    Text("Player 1: \(gameStateManager.player1.heartRate) BPM")
                }
                
                VStack {
                    WaveformBreathingCircle(
                        bpm: .constant(gameStateManager.player2.heartRate),
                        shouldAnimate: .constant(true)
                    ) {
                        // Cycle complete
                    }
                    .frame(width: 140, height: 140)
                    
                    Text("Player 2: \(gameStateManager.player2.heartRate) BPM")
                }
                
                VStack {
                    WaveformBreathingCircle(
                        bpm: .constant(gameStateManager.player3.heartRate),
                        shouldAnimate: .constant(true)
                    ) {
                        // Cycle complete
                    }
                    .frame(width: 140, height: 140)
                    
                    Text("Player 3: \(gameStateManager.player3.heartRate) BPM")
                }
            }
            
            // Controls
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
            }
            .padding()
        }
        .padding()
        .onAppear {
            if let startTime = gameStateManager.gameStartTime {
                timeRemaining = gameStateManager.gameDuration - Date().timeIntervalSince(startTime)
                if timeRemaining <= 0 {
                    gameStateManager.endGame()
                }
            } else {
                timeRemaining = gameStateManager.gameDuration
            }
        }
        .onReceive(timer) { _ in
            if let startTime = gameStateManager.gameStartTime {
                timeRemaining = gameStateManager.gameDuration - Date().timeIntervalSince(startTime)
                if timeRemaining <= 0 {
                    gameStateManager.endGame()
                }
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// PausedScreen.swift
import SwiftUI

struct PausedScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Experience Paused")
                .font(.largeTitle)
            
            Text("Take a moment to breathe...")
                .font(.title2)
            
            HStack(spacing: 20) {
                Button("Resume") {
                    gameStateManager.resumeGame()
                }
                .buttonStyle(.borderedProminent)
                
                Button("End Experience") {
                    gameStateManager.endGame()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding(.top, 40)
        }
        .padding()
    }
}

// ResultsScreen.swift
import SwiftUI

struct ResultsScreen: View {
    @ObservedObject var gameStateManager: GameStateManager
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Experience Complete")
                .font(.largeTitle)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Synchronization Score: \(Int(gameStateManager.calculateSynchronization()))%")
                    .font(.title3)
                
                if let startTime = gameStateManager.gameStartTime {
                    Text("Duration: \(formattedDuration(from: startTime))")
                        .font(.title3)
                }
                
                // More stats could go here
            }
            .padding()
            .frame(maxWidth: 500)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
            
            Text("Thank you for participating in Resonance")
                .font(.title2)
                .padding(.top)
            
            Button("Start New Experience") {
                gameStateManager.resetGame()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .padding()
    }
    
    private func formattedDuration(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d min %d sec", minutes, seconds)
    }
}
