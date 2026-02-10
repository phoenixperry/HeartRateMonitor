import Foundation

/// Generates fake BPM data for N simulated players.
/// In setup/ready phase, BPMs fluctuate randomly.
/// In playing phase, BPMs gradually converge toward a shared target.
class SimulatedHeartRateProvider {
    private var timer: Timer?
    private var playerBPMs: [Int]
    private var startingBPMs: [Int]
    private let targetBPM: Int
    private var isPlaying: Bool = false
    private var playElapsed: Int = 0
    private let gameDuration: Int = 180

    /// Called each tick with (playerIndex, newBPM)
    var onUpdate: ((Int, Int) -> Void)?

    let playerCount: Int

    init(playerCount: Int) {
        self.playerCount = playerCount
        // Randomize starting BPMs between 60-80
        self.playerBPMs = (0..<playerCount).map { _ in Int.random(in: 60...80) }
        self.startingBPMs = self.playerBPMs
        // Convergence target between 65-75
        self.targetBPM = Int.random(in: 65...75)
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func startPlaying() {
        isPlaying = true
        playElapsed = 0
        // Snapshot current BPMs as starting points for convergence
        startingBPMs = playerBPMs
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        playElapsed = 0
    }

    func bpm(for playerIndex: Int) -> Int {
        guard playerIndex >= 0 && playerIndex < playerBPMs.count else { return 0 }
        return playerBPMs[playerIndex]
    }

    private func tick() {
        if isPlaying {
            playElapsed += 1
            let progress = min(Double(playElapsed) / Double(gameDuration), 1.0)

            for i in 0..<playerCount {
                // Lerp from starting BPM toward target
                let lerped = Double(startingBPMs[i]) + (Double(targetBPM) - Double(startingBPMs[i])) * progress
                // Add diminishing noise: ±3 early, ±1 late
                let noiseRange = max(1, Int(3.0 * (1.0 - progress)))
                let noise = Int.random(in: -noiseRange...noiseRange)
                playerBPMs[i] = clamp(Int(lerped) + noise, low: 55, high: 85)
                onUpdate?(i, playerBPMs[i])
            }
        } else {
            // Setup/ready phase: random fluctuation ±1-2
            for i in 0..<playerCount {
                let delta = Int.random(in: -2...2)
                playerBPMs[i] = clamp(playerBPMs[i] + delta, low: 55, high: 85)
                onUpdate?(i, playerBPMs[i])
            }
        }
    }

    private func clamp(_ value: Int, low: Int, high: Int) -> Int {
        min(high, max(low, value))
    }
}
