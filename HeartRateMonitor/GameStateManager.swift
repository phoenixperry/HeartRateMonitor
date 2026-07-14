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

    // Envelope streaming (V: frames to the hardware, ~30 Hz)
    private var envelopeTimer: Timer? = nil
    private var envLastTick: Date? = nil

    // The oscillators behind the V: stream, plus the sync-group logic
    // (who breathes together, at what tempo). Owns what used to be the
    // envPhase/envBPM dictionaries — one owner of oscillator state. The
    // play screen binds its Lock/Release steppers to this too.
    let syncEngine = SyncEngine()

    // Y: dedup — last sync state sent to the hardware, plus a slow refresh
    // counter so an ESP reboot mid-round repaints the right strip colour.
    private var lastSentSyncLED: Bool? = nil
    private var syncLEDRefreshCounter = 0

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
                player.tileChannel = configManager.config.channel(forPlayerIndex: i)
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
                player.tileChannel = configManager.config.channel(forPlayerIndex: index)
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

    // MARK: - Envelope streaming (V: frames)

    // Stream every player's breathing-circle value to the hardware at ~30 Hz
    // ("V:<v1>,...,<v6>", 0-100 per slot) so the motors mirror the visuals
    // exactly. SyncEngine computes the values with the SAME math as
    // WaveformBreathingCircle (accumulated phase, tempo applied only at the
    // wrap — no view lifecycle involved), and layers the sync groups on top:
    // locked players' slots carry their group's shared envelope. Stopped by
    // pauseGame()/endGame()/resetGame().
    private func startEnvelopeStreaming() {
        stopEnvelopeStreaming()
        // Everyone solo, every phase back to the most-contracted point, every
        // tempo re-seeded from the live sensor — this is what makes RESUME
        // restart cleanly instead of un-freezing mid-breath.
        syncEngine.clearGroups(resetPhasesToZero: true)
        lastSentSyncLED = nil
        syncLEDRefreshCounter = 0
        envLastTick = nil
        envelopeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.sendEnvelopeFrame()
        }
    }

    private func stopEnvelopeStreaming() {
        envelopeTimer?.invalidate()
        envelopeTimer = nil
    }

    private func sendEnvelopeFrame() {
        let nowD = Date()
        let dt = envLastTick.map { nowD.timeIntervalSince($0) } ?? 0
        envLastTick = nowD
        guard dt > 0, dt < 0.25 else { return }   // first tick / timer hiccup
                                                  // (skipped frame = no tick —
                                                  // never advance on made-up dt)

        let samples = players.map {
            SyncEngine.PlayerSample(
                id: $0.id,
                bpm: $0.heartRate,
                active: $0.hasStartedPlay && $0.isConnected && $0.heartRate > 0
            )
        }
        let envelopes = syncEngine.tick(dt: dt, players: samples)

        // SyncEngine keys envelopes by player id; the hardware frame is indexed
        // by physical tile channel. Route each player's value to the tile they
        // were assigned so the motors/lights mirror the visuals on the right
        // hex, even when a player has been placed on a non-default tile.
        var values = [Int](repeating: 0, count: 6)   // absent tiles stay 0
        for player in players {
            guard let env = envelopes[player.id], (1...6).contains(player.tileChannel) else { continue }
            values[player.tileChannel - 1] = Int((env * 100).rounded())
        }
        espManager.sendEnvelope(values)

        // Strip pink ONLY when every active player is locked in one group —
        // a 2-of-4 sync keeps its haptic/audio cue but the room stays white.
        // Edge-triggered, with a ~1 s refresh so an ESP reboot self-heals.
        let allSynced = syncEngine.allActiveInOneGroup
        syncLEDRefreshCounter += 1
        if allSynced != lastSentSyncLED || syncLEDRefreshCounter >= 30 {
            espManager.sendSyncState(allSynced)
            lastSentSyncLED = allSynced
            syncLEDRefreshCounter = 0
        }
    }

    // MARK: - Game Control

    // Start the game experience
    func startGame() {
        guard currentState == .ready else { return }

        // Only start play for connected players
        players.filter { $0.isConnected }.forEach { $0.startPlay() }

        // The operator sets the session length on the Configuration screen;
        // it's read once at start so mid-round config edits can't move the clock.
        gameDuration = configManager.config.effectiveGameDuration
        gameStartTime = Date()
        currentState = .playing
        startEnvelopeStreaming()

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
                // Record what was driving the haptic stimulus this second, so
                // coherence onset can be correlated with the actual stimulus.
                let stimulus: String
                if !self.espManager.isConnected {
                    stimulus = "no-haptics"
                } else if self.envelopeTimer != nil {
                    stimulus = "streaming"
                } else {
                    stimulus = "local-synth"
                }
                return LogDataPoint(playerBPMs: bpms, syncScore: syncScore,
                                    activePlayerCount: activeCount,
                                    stimulusCondition: stimulus)
            }
        }
    }

    // Pause the game: motors off (firmware P: state), all per-beat output
    // gated (K:/OSC/MIDI), envelope stream stopped, sound muted, and the
    // pause recorded in the research log so analysis can segment around it.
    func pauseGame() {
        guard currentState == .playing else { return }
        pauseStartTime = Date()
        currentState = .paused
        researchLogger.logEvent("pause")
        researchLogger.pauseSession()
        stopEnvelopeStreaming()
        players.forEach { $0.isGamePaused = true }   // gate K:/OSC/MIDI beats
        espManager.sendSyncState(false)              // pink never survives a pause
        lastSentSyncLED = false
        espManager.sendPause()                       // motors off within a frame
        AUEngine.shared.setMuted(true)               // volume 0 + notes off
    }

    // Resume the game: unmute, un-gate the beats, restart the envelope
    // stream, and wake the hardware (firmware R: exits its pause state).
    // startEnvelopeStreaming() clears the sync groups and restarts every
    // player from the most-contracted point at their live sensor BPM —
    // motors come back from silence, never mid-pulse.
    func resumeGame() {
        guard currentState == .paused else { return }
        if let pauseStart = pauseStartTime {
            totalPausedTime += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        currentState = .playing
        AUEngine.shared.setMuted(false)
        espManager.sendResume()
        players.forEach { $0.isGamePaused = false }
        startEnvelopeStreaming()
        researchLogger.resumeSession()
        researchLogger.logEvent("resume")
    }

    // End the game
    func endGame() {
        currentState = .finished
        // Stop streaming BEFORE sendDone(): a non-zero V: frame arriving after
        // D: would flip the firmware straight back into PLAY.
        stopEnvelopeStreaming()
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
        stopEnvelopeStreaming()
        researchLogger.endSession()
        simulationProvider?.stop()
        simulationProvider = nil

        // Full reset: groups gone, thresholds back to their defaults (the
        // operator's mid-round tweaks are session-only by design), strip
        // back to white-then-teal. The extra D:0 is cheap insurance for any
        // reset path that didn't come through endGame().
        syncEngine.clearGroups(resetPhasesToZero: true)
        syncEngine.resetThresholds()
        espManager.sendSyncState(false)
        lastSentSyncLED = nil
        espManager.sendDone()

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
