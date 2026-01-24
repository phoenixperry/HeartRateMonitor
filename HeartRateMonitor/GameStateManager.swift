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

    // Pause tracking
    private var pauseStartTime: Date? = nil
    @Published var totalPausedTime: TimeInterval = 0
    
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
    
    // Count of currently connected players
    var connectedPlayerCount: Int {
        [player1.isConnected, player2.isConnected, player3.isConnected].filter { $0 }.count
    }

    private func setupStateTransitions() {
        // Combine the connection state of all players to determine readiness
        Publishers.CombineLatest3(
            player1.$isConnected,
            player2.$isConnected,
            player3.$isConnected
        )
        .map { p1Connected, p2Connected, p3Connected in
            // Ready when at least one player is connected
            return p1Connected || p2Connected || p3Connected
        }
        .sink { [weak self] anyConnected in
            if anyConnected && self?.currentState == .setup {
                self?.currentState = .ready
            } else if !anyConnected && self?.currentState == .ready {
                // If all players disconnect before game starts, go back to setup
                self?.currentState = .setup
            }
            // During gameplay (.playing or .paused), allow players to leave without ending the round
        }
        .store(in: &cancellables)
    }
    
    // Start the game experience
    func startGame() {
        guard currentState == .ready else { return }

        // Only start play for connected players
        if player1.isConnected { player1.startPlay() }
        if player2.isConnected { player2.startPlay() }
        if player3.isConnected { player3.startPlay() }

        gameStartTime = Date()
        currentState = .playing
    }
    
    // Pause the game
    func pauseGame() {
        guard currentState == .playing else { return }
        pauseStartTime = Date()
        currentState = .paused
    }

    // Resume the game
    func resumeGame() {
        guard currentState == .paused else { return }
        if let pauseStart = pauseStartTime {
            totalPausedTime += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
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
        pauseStartTime = nil
        totalPausedTime = 0
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
