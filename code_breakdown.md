# HeartRateMonitor (aka "Resonance" / "beat_piece")

A **macOS SwiftUI app** that turns multi-player heart rates into a synchronized group experience. Players wear BLE heart rate monitors; the app streams their BPMs into haptics, sound, and visuals to coach the group toward physiological synchrony.

- **Working dir:** `/Users/phoenixperry/Documents/GitHub/beat_piece/HeartRateMonitor`
- **Current branch:** `Headless_Game` (other branches: `main`, `multiplayerosc`)
- **Author:** Phoenix Perry

## Architecture (5 layers)

### 1. App entry — `HeartRateMonitorApp.swift`
Builds shared `ESPPeripheralManager` + `ConfigurationManager`, hands both to a single `GameStateManager`. AppKit lifecycle via `AppDelegate`.

### 2. State machine — `GameStateManager.swift`
States: `configuring → setup → ready → playing ↔ paused → finished`. Holds a dynamic `players: [PlayerCardViewModel]` array (2–6 players, default 3). Auto-promotes setup→ready when any player connects. Computes a sync score (0–100%) from min/max BPM spread across active players (50 BPM range = 0%). Routes a `LogDataPoint` provider to `ResearchLogger` during play.

### 3. UI — `ContentView.swift` switches per state
- `ConfigurationScreen` (device discovery/pairing)
- `StartScreen` ("Resonance" branding, player grid, Begin button)
- `GameScreen` (sync %, REC indicator, countdown, Pause/End — 3 min default)
- `PausedScreen`, `ResultsScreen`
- `PlayerCardView` / `PlayerCardViewModel` per player

### 4. Device & data
- **`HeartRateManager`** — Standard BLE Heart Rate Service (`180D`, char `2A37`). One per real player. Auto-disconnects a player if their BPM drops to 0 mid-game.
- **`ESPPeripheralManager`** — Connects to an ESP32 named `HeartHapticsESP` (service `180D`, char `2A39`). Custom string protocol: `S:<id>:<bpm>` sets tempo, `K:<id>` fires haptics.
- **`NativeOSCManager`** (`OSCManager.swift`) — UDP OSC to `127.0.0.1:8000`. Per-player address `/player/<id>/bpm`, plus `/wek/bpm` bundle (Wekinator integration).
- **`ConfigurationManager`** — BLE scan, pair, assign players to UUIDs. Persists to `~/Library/Application Support/HeartRateMonitor/config.json`. Won't overwrite an existing file with empty config (recent bugfix).
- **`SerialManager` / `SerialDevicePicker`** — Serial fallback path.
- **`Persistence.swift`** — Core Data.

### 5. Simulation & research
- **`SimulatedHeartRateProvider`** — Fake BPMs for dev. Random fluctuation in setup; lerps toward a shared target with diminishing noise during play (drives the convergence demo). Toggled by `UserDefaults` key `SimulateHeartRateMonitors`.
- **`ResearchLogger`** — Singleton CSV logger (1 Hz sampling). Writes to `~/Library/Mobile Documents/com~apple~CloudDocs/beat_piece/logs/resonance_log_YYYY-MM-DD.csv`. Header + session markers, up to 6 player columns + sync score + active count. Gated by `EnableResearchLogging` UserDefault.

### 6. Graphics
Metal shaders (`BasicShader.metal`, `ResonanceShaders.metal`) and SwiftUI breathing visualizations (`EnhancedBreathingCircle`, `WaveformBreathingCircle`, `MetalShaderView`, etc.). The main `GameScreen` currently uses the plain player grid; a richer `GameScreenWithShaders` variant exists.

## Notable details
- macOS-only (uses `AppKit`, `NSWorkspace`, `NSApplicationDelegateAdaptor`).
- README is a high-level overview; no `CLAUDE.md` exists.
- Recent commit cadence focuses on robustness: simulated mode, research logging, config persistence fix, auto-disconnect on flatline, dynamic 1–3 player starts.
- CI: GitHub Actions Swift workflow (`.github/workflows/swift.yml`).

## Outputs the app emits during play
1. **BLE → ESP32**: `S:id:bpm` tempo + `K:id` haptic kicks (one per player heartbeat cycle).
2. **OSC → localhost:8000**: per-player BPM for downstream audio (Wekinator/SuperCollider/Max etc.).
3. **CSV → iCloud Drive**: timestamped sync data for research analysis.
