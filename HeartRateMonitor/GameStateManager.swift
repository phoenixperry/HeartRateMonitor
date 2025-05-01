import Foundation
import SwiftUI
import Combine

// Defines the possible states of the game
enum GameState {
    case setup       // Initial setup, connecting devices
    case ready       // All players connected, ready to start
    case playing     // Active gameplay
    case paused      // Game temporarily paused
    case finished    // Game completed
}

class GameStateManager: ObservableObject {
    // Current game state
    @Published var currentState: GameState = .setup
    
    // Player references (maintained across views)
    let player1: PlayerCardViewModel
    let player2: PlayerCardViewModel
    let player3: PlayerCardViewModel
    
    // Haptic/connection manager
    let espManager: ESPPeripheralManager
    
    // Game metrics
    @Published var gameStartTime: Date? = nil
    @Published var gameDuration: TimeInterval = 180 // 3 minutes default
    @Published var synchronizationScore: Double = 0
    
    // For tracking state changes
    private var cancellables = Set<AnyCancellable>()
    
    init(player1: PlayerCardViewModel, player2: PlayerCardViewModel, player3: PlayerCardViewModel, espManager: ESPPeripheralManager) {
        self.player1 = player1
        self.player2 = player2
        self.player3 = player3
        self.espManager = espManager
        
        // Setup observers for ready state
        setupStateTransitions()
    }
    
    private func setupStateTransitions() {
        // Combine the connection state of all players to determine readiness
        Publishers.CombineLatest3(
            player1.$isConnected,
            player2.$isConnected,
            player3.$isConnected
        )
        .map { p1Connected, p2Connected, p3Connected in
            return p1Connected && p2Connected && p3Connected
        }
        //sink says, "Hey, I want to know about any changes that happen in this data stream, and here's what I want to do when changes occur."
        .sink { [weak self] allConnected in
            if allConnected && self?.currentState == .setup {
                self?.currentState = .ready
            } else if !allConnected && (self?.currentState == .ready || self?.currentState == .playing) {
                // If someone disconnects during gameplay, pause
                self?.currentState = .setup
            }
        }
        .store(in: &cancellables)
    }
    
    // Start the game experience
    func startGame() {
        guard currentState == .ready else { return }
        
        // Set all players to playing state
        player1.startPlay()
        player2.startPlay()
        player3.startPlay()
        
        gameStartTime = Date()
        currentState = .playing
    }
    
    // Pause the game
    func pauseGame() {
        guard currentState == .playing else { return }
        currentState = .paused
    }
    
    // Resume the game
    func resumeGame() {
        guard currentState == .paused else { return }
        currentState = .playing
    }
    
    // End the game
    func endGame() {
        currentState = .finished
    }
    
    // Reset everything to beginning
    func resetGame() {
        player1.disconnect()
        player2.disconnect()
        player3.disconnect()
        
        gameStartTime = nil
        synchronizationScore = 0
        currentState = .setup
    }
    
    // Calculate how synchronized the heart rates are (0-100%)
    func calculateSynchronization() -> Double {
        // Get the three heart rates
        let rates = [player1.heartRate, player2.heartRate, player3.heartRate]
        
        // Filter out zeros (players not reporting)
        let activeRates = rates.filter { $0 > 0 }
        
        // Need at least 2 active players to measure synchronization
        guard activeRates.count >= 2 else { return 0 }
        
        // Find the range between min and max
        if let minRate = activeRates.min(), let maxRate = activeRates.max() {
            let range = maxRate - minRate
            
            // Calculate how synchronized they are
            // 0 = perfect sync, higher numbers = less sync
            // Convert to a 0-100% score where 100% is perfect sync
            let maxPossibleRange = 50 // Theoretical max difference we care about
            let syncScore = 100.0 * (1.0 - (Double(range) / Double(maxPossibleRange)))
            
            // Clamp between 0-100
            return Swift.min(100, Swift.max(0, syncScore))
        }
        
        return 0
    }
}
