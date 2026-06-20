# Session handoff — 2026-06-20

Quick context dump so we can pick up cleanly.

## Where we are right now

The big arc of this session: **wire the Arturia MiniFreak V plugin into the app so heartbeats drive synth notes, and bond the hardware MiniFreak to the plugin for tactile control during installations.**

State at the moment of stopping:

- ✅ MiniFreak V loads inside the app (`AUEngine.swift`)
- ✅ Per-heartbeat MIDI notes fire (P1=C2 … P6=C5)
- ✅ Audio comes out cleanly
- ✅ Auto-connect on Save & Continue works
- ✅ Player UI redesign done in Space Grotesk + DM Sans, black-on-white, traffic-lights titlebar
- ✅ Config screen redesign done (monochrome, radial toggles, custom monochrome stepper)
- ✅ Hardware MIDI bridge wired (`AUEngine` opens a CoreMIDI port, listens to any device whose name contains "MiniFreak", forwards every byte into the plugin via `scheduleMIDIEventBlock`)
- ⚠️ Hardware → plugin **note + CC** flow should now work via the bridge
- ❌ Hardware → plugin **patch sync** isn't working (Phoenix confirmed it also doesn't work in Ableton — so it's an Arturia setup/firmware issue, not our code)
- ❌ Plugin settings panel won't open inside our host window (gear button "flashes but nothing opens"). Likely a JUCE child-window-parenting issue in our `NSWindow` setup. Workaround: use the standalone `MiniFreak V.app` to configure / save preset, then load that preset in our host.

## Next steps when you come back

In rough order of priority:

1. **Rebuild + run** and check console for the new bridge log line:
   `🎹 MIDI bridge: connected to MiniFreak`
   If you see `no MiniFreak device found in CoreMIDI sources`, we need to widen the name match (currently `localizedCaseInsensitiveContains("MiniFreak")` in `AUEngine.swift`).
2. **Test the bridge**: play the hardware MiniFreak keyboard → expect notes through the plugin in our app. Turn a knob on the hardware → expect the plugin's matching knob to move.
3. **Diagnose patch-sync failure** (this is the same problem in Ableton, so it's about firmware / settings, not our code):
   - Arturia Software Center → confirm both MiniFreak hardware firmware and MiniFreak V plugin are up to date
   - In the plugin's settings panel, look for a "Sync to Hardware" or "Connect to Hardware" toggle and confirm it's on (this likely requires you to open settings in the standalone app, since our host can't open them)
   - Check MIDI channel matches between hardware and plugin (default both to channel 1)
4. **If we want to fix the settings-panel-won't-open issue in our host**, that's a JUCE-style child window parenting problem. Realistic options:
   - Add `acceptsMouseMovedEvents = true` to the plugin `NSWindow` and remove `NSApp.activate(ignoringOtherApps: true)` (might be stealing focus from a child window the moment it opens)
   - Switch from `window.contentViewController = vc` to `window.contentView = vc.view` so JUCE manages its own subwindows directly
   - Either way, this is "throw spaghetti and see what sticks" territory — none guaranteed

## Files we touched today

| File | Purpose |
|---|---|
| `HeartRateMonitor/AUEngine.swift` | AU host + CoreMIDI hardware bridge (new this session) |
| `HeartRateMonitor/PlayerCardViewModel.swift` | Added the `AUEngine.shared.noteOnIfEnabled(...)` call in `cycleDidComplete`; also fire-on-first-BPM optimization |
| `HeartRateMonitor/WaveformBreathingCircle.swift` | Bootstrap fix — first BPM arrival now jumps the cycle clock directly instead of waiting 60 s |
| `HeartRateMonitor/HeartRateManager.swift` | Reverted to plain BLE 2A37 parsing (ghost detection removed) |
| `HeartRateMonitor/MonitorLivenessProber.swift` | Reverted to plain BLE 2A37 parsing |
| `HeartRateMonitor/ConfigurationScreen.swift` | "Drive Arturia MiniFreak V" radial toggle + "Open plugin" button in Dev Settings |
| `HeartRateMonitor/ConfigurationManager.swift` | Owns `MonitorLivenessProber`, `isDeviceLive(_:)`, start/stop probing |
| `HeartRateMonitor/HeartRateMonitor.entitlements` | Sandbox off + `cs.disable-library-validation` + `cs.allow-jit` + `cs.allow-unsigned-executable-memory` — required to host AUv2 plugins under Hardened Runtime |
| `HeartRateMonitor/Info.plist` | Renamed from `info.plist` (case-fix; broke a build-phase ref, also fixed) |
| `HeartRateMonitor/AppDelegate.swift` | Calls `AUEngine.shared.shutdown()` on quit to avoid the MiniFreak EXC_BAD_ACCESS on app exit |
| `HRMeasurement.swift` | **Deleted** — we tried Polar ghost-detection (contact bit + RR variance) and neither worked for OH1/Sense |

## Tricky things to remember

- **Build flow**: rebuild requires `Shift+Cmd+K` (Clean Build Folder) any time entitlements change. Without that you'll keep running the old signed bundle with the old entitlements and get `-3000` on AU instantiate.
- **Entitlements lived in three places initially**. We now have *one* correct entitlements file at `HeartRateMonitor/HeartRateMonitor.entitlements` (the nested one). The other two at the repo root are deleted. Build Settings → "Code Signing Entitlements" points at the nested one.
- **Build target membership**: each new `.swift` file we add (this session that was `AUEngine.swift`, `MonitorLivenessProber.swift`) needs to be ticked into the HeartRateMonitor target via File Inspector → Target Membership. Otherwise SourceKit complains AND the build actually fails.
- **SourceKit phantoms vs real errors**: 95% of "Cannot find type X in scope" messages we saw this session were cross-file SourceKit indexing noise that resolves at build time. But occasionally one is real (today: `AVAudioUnitMIDIInstrument` has no `sendMIDISysEx` on macOS — switched to `AUAudioUnit.scheduleMIDIEventBlock`).
- **Polar ghost period**: OH1 / Sense (optical) keep emitting BPM for ~1–2 min after removal, with convincingly varied RR data. There's no reliable BLE-side way to detect this without false-positiving people sitting still. Accept hardware limitation; rely on the per-card Disconnect button when someone needs to step out.
- **AUv2 hosting + Hardened Runtime**: the three entitlements above are non-negotiable for loading Arturia plugins. Re-sandboxing for distribution will break AU hosting — keep in mind for ship time.
- **App quit teardown**: `AUEngine.shutdown()` MUST run before `engine.stop()` returns to dyld, otherwise MiniFreak's render thread will crash on freed memory.

## Useful console signal vocabulary

- `🎹 AUEngine: MiniFreak V loaded and engine started.` — plugin is up
- `🎹 noteOn  P<id> note=<n> vel=96` — heartbeat fired a MIDI note
- `🎹 MIDI bridge: connected to <device>` — hardware MIDI bridge wired (NEW today)
- `🎹 MIDI bridge: no MiniFreak device found in CoreMIDI sources` — bridge couldn't find your hardware (try widening the name match in `AUEngine.swift`)
- `🎹 AUEngine: shut down cleanly.` — clean exit
- `▶️ Player N started play` — player joined the group
- `💔 Player N heart rate dropped to 0 - disconnecting` — auto-disconnect on flatline

## Outstanding deferred follow-ups

- **Clean signed `.app` for the installation Mac**: still owe Phoenix this. Path is Xcode → Product → Archive → Organizer → Distribute App → Copy App. Memory note in `~/.claude/projects/-Users-phoenixperry-Documents-GitHub-beat-piece-HeartRateMonitor/memory/project_clean_app_copy.md`.
- **`CODE_SIGN_IDENTITY = HeartRateMonitor.entitlements`** in `project.pbxproj` — nonsense value, Xcode is ignoring it but worth cleaning up next time you touch the Signing & Capabilities tab.
- **Six-instance per-player synth**: deferred for if/when Phoenix wants each player to have their own timbre instead of all six sharing the MiniFreak voice with different pitches.

## What we removed this session (no longer worth re-trying)

- BLE Sensor Contact bit + RR-interval variance ghost detection. Polar firmware is too good at faking varied data after removal. Both guards were stripped (`HRMeasurement.swift` deleted, inline parsing restored in `HeartRateManager` and `MonitorLivenessProber`). Don't reinstate without a new signal — option 3 (BPM-stuck timeout) would false-positive resting users.

## How to restart cleanly

1. `cd /Users/phoenixperry/Documents/GitHub/beat_piece/HeartRateMonitor`
2. Open `HeartRateMonitor.xcodeproj` in Xcode
3. Shift+Cmd+K to clean
4. Cmd+R to build & run
5. In the app: Configuration → flip on **Drive Arturia MiniFreak V** toggle (if it isn't already on)
6. Connect a Polar strap, wear it, Join the group, verify heartbeats fire notes
7. Plug in the MiniFreak hardware via USB, watch console for the `🎹 MIDI bridge: connected to MiniFreak` line, then play a key on the hardware → expect sound

Welcome back, future Phoenix / Claude. Have fun.
