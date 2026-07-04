import Foundation
import SwiftUI
import Combine

// Defines the possible states of the game
enum GameState {
    case configuring // Showing configuration screen
    case setup       // Initial setup, connecting devices
    case ready       // At least one player connected, ready to start
    case playing     // Active gameplay
    case paused      // Game temporarily paused
    case finished    // Game completed
}

class GameStateManager: ObservableObject {
    // Current game state
    @Published var currentState: GameState = .setup

    // Dynamic player array (replaces fixed player1/2/3)
    @Published var players: [PlayerCardViewModel] = []

    // Haptic/connection manager
    let espManager: ESPPeripheralManager

    // Configuration manager reference
    private let configManager: ConfigurationManager

    // Research logger reference
    private let researchLogger = ResearchLogger.shared

    // Simulation
    private var simulationProvider: SimulatedHeartRateProvider?

    var isSimulationEnabled: Bool {
        UserDefaults.standard.bool(forKey: "SimulateHeartRateMonitors")
    }

    // Game metrics
    @Published var gameStartTime: Date? = nil
    @Published var gameDuration: TimeInterval = 180 // 3 minutes default
    @Published var synchronizationScore: Double = 0

    // Pause tracking
    private var pauseStartTime: Date? = nil
    @Published var totalPausedTime: TimeInterval = 0

    // For tracking state changes
    private var cancellables = Set<AnyCancellable>()

    init(espManager: ESPPeripheralManager, configManager: ConfigurationManager) {
        self.espManager = espManager
        self.configManager = configManager

        // Build players from config
        rebuildPlayers()

        // Setup observers for ready state
        setupStateTransitions()
    }

    // MARK: - Player Management

    /// Rebuilds the players array from the current configuration
    func rebuildPlayers() {
        // Disconnect and clear existing players
        players.forEach { $0.disconnect() }
        players.removeAll()
        cancellables.removeAll()
        simulationProvider?.stop()
        simulationProvider = nil

        if isSimulationEnabled {
            let count = configManager.config.playerCount
            // Create simulated players with dummy UUIDs
            for i in 0..<count {
                let player = PlayerCardViewModel(
                    id: i + 1,
                    deviceUUID: UUID(),
                    espManager: espManager,
                    simulated: true
                )
                player.isConnected = true
                players.append(player)
            }

            // Create and start simulation provider
            let provider = SimulatedHeartRateProvider(playerCount: count)
            provider.onUpdate = { [weak self] index, bpm in
                guard let self = self, index < self.players.count else { return }
                self.players[index].updateSimulatedBPM(bpm)
            }
            provider.start()
            self.simulationProvider = provider

            print("🔄 Rebuilt \(players.count) simulated players")
        } else {
            // Create real players from config
            for (index, uuid) in configManager.config.selectedPlayerUUIDs.prefix(configManager.config.playerCount).enumerated() {
                let player = PlayerCardViewModel(
                    id: index + 1,
                    deviceUUID: uuid,
                    espManager: espManager
                )
                players.append(player)
            }
            print("🔄 Rebuilt \(players.count) players from config")
        }

        // Re-setup state transitions for new players
        setupStateTransitions()
    }

    // Count of currently connected players
    var connectedPlayerCount: Int {
        players.filter { $0.isConnected }.count
    }

    // Total player count from config
    var playerCount: Int {
        configManager.config.playerCount
    }

    private func setupStateTransitions() {
        // Clear existing subscriptions
        cancellables.removeAll()

        guard !players.isEmpty else { return }

        // Create publishers for all player connection states
        let connectionPublishers = players.map { $0.$isConnected }

        // Merge all connection state changes
        Publishers.MergeMany(connectionPublishers)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                let anyConnected = self.players.contains { $0.isConnected }

                if anyConnected && self.currentState == .setup {
                    self.currentState = .ready
                } else if !anyConnected && self.currentState == .ready {
                    // If all players disconnect before game starts, go back to setup
                    self.currentState = .setup
                }
                // During gameplay (.playing or .paused), allow players to leave without ending the round
            }
            .store(in: &cancellables)
    }

    // MARK: - Game Control

    // Start the game experience
    func startGame() {
        guard currentState == .ready else { return }

        // Only start play for connected players
        players.filter { $0.isConnected }.forEach { $0.startPlay() }

        gameStartTime = Date()
        currentState = .playing

        if isSimulationEnabled {
            // Switch simulation to convergence mode
            simulationProvider?.startPlaying()
        } else {
            // Start research logging with data provider (skip during simulation)
            researchLogger.startSession(playerCount: playerCount) { [weak self] in
                guard let self = self else {
                    return LogDataPoint(playerBPMs: [], syncScore: 0, activePlayerCount: 0)
                }
                let bpms = self.players.map { $0.heartRate }
                let syncScore = self.calculateSynchronization()
                let activeCount = self.connectedPlayerCount
                return LogDataPoint(playerBPMs: bpms, syncScore: syncScore, activePlayerCount: activeCount)
            }
        }
    }

    // Pause the game
    func pauseGame() {
        guard currentState == .playing else { return }
        pauseStartTime = Date()
        currentState = .paused
        researchLogger.pauseSession()
    }

    // Resume the game
    func resumeGame() {
        guard currentState == .paused else { return }
        if let pauseStart = pauseStartTime {
            totalPausedTime += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        currentState = .playing
        researchLogger.resumeSession()
    }

    // End the game
    func endGame() {
        currentState = .finished
        simulationProvider?.stop()
        researchLogger.endSession()
        espManager.sendDone()
    }

    // Reset everything to beginning. Crucially we do *not* BLE-disconnect
    // the players — straps stay paired and reading BPM, so the Setup screen
    // shows them already connected and the operator doesn't have to walk
    // back through Configuration just to re-pair after every round. Each
    // player still has to tap "Join the group" again because hasStartedPlay
    // is cleared. Going back into Configuration remains optional via the
    // gear in the toolbar.
    func resetGame() {
        researchLogger.endSession()
        simulationProvider?.stop()
        simulationProvider = nil

        DispatchQueue.main.async { [weak self] in
            self?.players.forEach { $0.hasStartedPlay = false }
        }

        gameStartTime = nil
        synchronizationScore = 0
        pauseStartTime = nil
        totalPausedTime = 0
        // If any player is already connected (the usual case now that we
        // don't BLE-disconnect on reset), go straight to .ready so the
        // "Begin experience" button is visible. The publisher-based
        // .setup → .ready transition only fires on isConnected *changes*
        // and no change happens here, so we have to nudge it manually.
        currentState = players.contains(where: { $0.isConnected }) ? .ready : .setup
    }

    // Open configuration screen
    func openConfiguration() {
        currentState = .configuring
    }

    // Close configuration screen and rebuild players
    func closeConfiguration() {
        rebuildPlayers()
        currentState = .setup
        // Smooth the handoff: kick off BLE connection for each real player immediately.
        // Per-player "Join the group!" stays manual — only the connect step is automatic.
        // connect() is deferral-aware, so it's safe even if the new HeartRateManager's
        // central hasn't reached .poweredOn yet.
        for player in players where !player.isSimulated {
            player.connect()
        }
    }

    // MARK: - Calculations

    // Calculate how synchronized the heart rates are (0-100%)
    func calculateSynchronization() -> Double {
        // Get all heart rates from players
        let rates = players.map { $0.heartRate }

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
