//
//  ResearchLogger.swift
//  HeartRateMonitor
//
//  Research data logging system for capturing heart rate synchronization data
//

import Foundation
import AppKit

class ResearchLogger {
    static let shared = ResearchLogger()

    // MARK: - Configuration

    private let userDefaultsKey = "EnableResearchLogging"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: userDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }

    // MARK: - Session State

    private var sessionId: String?
    private var sessionStartTime: Date?
    private var elapsedSeconds: Int = 0
    private var pausedElapsedSeconds: Int = 0
    private var isPaused: Bool = false
    private var recordCount: Int = 0
    private var playerCount: Int = 0

    private var samplingTimer: Timer?
    private var fileHandle: FileHandle?
    private var currentFilePath: URL?

    // Data provider closure - set by GameStateManager
    private var dataProvider: (() -> LogDataPoint)?

    // Published for UI observation
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var currentRecordCount: Int = 0
    private(set) var lastSessionRecordCount: Int = 0

    // MARK: - Directory Management

    /// Logs directory on iCloud Drive for easy access
    var logsDirectoryURL: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/beat_piece/logs")
    }

    private init() {}

    // MARK: - Session Lifecycle

    /// Start a new logging session
    /// - Parameters:
    ///   - playerCount: Number of players in this session
    ///   - dataProvider: Closure that returns current data point for logging
    func startSession(playerCount: Int, dataProvider: @escaping () -> LogDataPoint) {
        guard isEnabled else { return }

        self.playerCount = playerCount
        self.dataProvider = dataProvider
        self.sessionId = generateSessionId()
        self.sessionStartTime = Date()
        self.elapsedSeconds = 0
        self.pausedElapsedSeconds = 0
        self.isPaused = false
        self.recordCount = 0

        // Ensure logs directory exists
        createLogsDirectoryIfNeeded()

        // Open or create today's log file
        openLogFile()

        // Write session header
        writeSessionHeader()

        // Start sampling timer
        startSamplingTimer()

        isRecording = true
        currentRecordCount = 0

        print("📊 Research logging started: session \(sessionId ?? "unknown")")
    }

    /// Pause the logging session (timer keeps running but no data captured)
    func pauseSession() {
        guard isEnabled, sessionId != nil else { return }
        isPaused = true
        pausedElapsedSeconds = elapsedSeconds
        print("📊 Research logging paused at \(elapsedSeconds)s")
    }

    /// Resume the logging session
    func resumeSession() {
        guard isEnabled, sessionId != nil else { return }
        isPaused = false
        print("📊 Research logging resumed")
    }

    /// End the logging session and close the file
    func endSession() {
        guard isEnabled, sessionId != nil else { return }

        // Stop timer
        samplingTimer?.invalidate()
        samplingTimer = nil

        // Get final sync score before closing
        let finalSync = dataProvider?().syncScore ?? 0

        // Write session footer
        writeSessionFooter(finalSync: finalSync)

        // Close file handle
        closeLogFile()

        print("📊 Research logging ended: \(recordCount) records, final sync: \(String(format: "%.1f", finalSync))%")

        // Store final count for ResultsScreen display
        lastSessionRecordCount = recordCount

        // Reset state
        isRecording = false
        sessionId = nil
        sessionStartTime = nil
        dataProvider = nil
    }

    /// Open the logs folder in Finder
    func openLogsFolder() {
        createLogsDirectoryIfNeeded()
        NSWorkspace.shared.open(logsDirectoryURL)
    }

    // MARK: - File Management

    private func createLogsDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logsDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
                print("📁 Created logs directory: \(logsDirectoryURL.path)")
            } catch {
                print("❌ Failed to create logs directory: \(error)")
            }
        }
    }

    private func openLogFile() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        let fileName = "resonance_log_\(dateString).csv"
        currentFilePath = logsDirectoryURL.appendingPathComponent(fileName)

        guard let filePath = currentFilePath else { return }

        let fileManager = FileManager.default
        let isNewFile = !fileManager.fileExists(atPath: filePath.path)

        // Create file if it doesn't exist
        if isNewFile {
            fileManager.createFile(atPath: filePath.path, contents: nil)
        }

        do {
            fileHandle = try FileHandle(forWritingTo: filePath)
            fileHandle?.seekToEndOfFile()

            // Write CSV header for new files
            if isNewFile {
                writeCSVHeader()
            }
        } catch {
            print("❌ Failed to open log file: \(error)")
        }
    }

    private func closeLogFile() {
        do {
            try fileHandle?.close()
        } catch {
            print("❌ Failed to close log file: \(error)")
        }
        fileHandle = nil
        currentFilePath = nil
    }

    // MARK: - CSV Writing

    private func writeCSVHeader() {
        // Build dynamic header based on max possible players
        var header = "timestamp,elapsed_seconds"
        for i in 1...6 {
            header += ",player\(i)_bpm"
        }
        header += ",sync_score,player_count_active,stimulus_condition\n"

        writeLine(header)
    }

    private func writeSessionHeader() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let header = "# SESSION_START,\(timestamp),\(sessionId ?? "unknown"),players=\(playerCount)\n"
        writeLine(header)
    }

    /// Log a discrete session event (pause, resume, …) as a comment row so
    /// analysis can segment the 1 Hz samples around it. No-op if no session
    /// file is open.
    func logEvent(_ name: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        writeLine("# EVENT,\(timestamp),\(name)\n")
    }

    private func writeSessionFooter(finalSync: Double) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let duration = elapsedSeconds
        let footer = "# SESSION_END,\(timestamp),\(sessionId ?? "unknown"),duration_seconds=\(duration),final_sync=\(String(format: "%.1f", finalSync)),total_records=\(recordCount)\n"
        writeLine(footer)
    }

    private func writeDataRow(_ dataPoint: LogDataPoint) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var row = "\(timestamp),\(elapsedSeconds)"

        // Add BPM for each player slot (up to 6)
        for i in 0..<6 {
            if i < dataPoint.playerBPMs.count {
                row += ",\(dataPoint.playerBPMs[i])"
            } else {
                row += ","
            }
        }

        row += ",\(String(format: "%.1f", dataPoint.syncScore)),\(dataPoint.activePlayerCount),\(dataPoint.stimulusCondition)\n"

        writeLine(row)
        recordCount += 1
        currentRecordCount = recordCount
    }

    private func writeLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        fileHandle?.write(data)
    }

    // MARK: - Sampling Timer

    private func startSamplingTimer() {
        samplingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
    }

    private func timerTick() {
        guard !isPaused else { return }

        elapsedSeconds += 1

        // Capture and write data point
        if let dataPoint = dataProvider?() {
            writeDataRow(dataPoint)
        }
    }

    // MARK: - Helpers

    private func generateSessionId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let randomPart = String((0..<6).map { _ in chars.randomElement()! })
        return "session_\(randomPart)"
    }
}

// MARK: - Data Types

struct LogDataPoint {
    let playerBPMs: [Int]      // BPM for each player (0 if disconnected)
    let syncScore: Double       // Current synchronization score
    let activePlayerCount: Int  // Number of currently connected players
    // What was driving the haptic stimulus this second (for correlating
    // coherence onset with what the motors were actually doing):
    //   "streaming"   — app was sending V: envelope frames (motors mirror circles)
    //   "local-synth" — ESP connected, firmware synthesizing from S:/K:
    //   "no-haptics"  — ESP not connected, no haptic stimulus at all
    var stimulusCondition: String = "unknown"
}
