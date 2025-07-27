

Here's a high-level overview of this project's codebase architecture, based on the main files and their roles:
1. App Entry Point
HeartRateMonitorApp.swift
This is the main entry point for your SwiftUI app.
It sets up the core managers (like ESPPeripheralManager for device communication) and creates three player view models.
It initializes the GameStateManager, which orchestrates the game state and player management.
The main window displays the ContentView, passing in the GameStateManager.
2. State & Game Management
GameStateManager.swift
Central class for managing the overall game state (setup, ready, playing, paused, finished).
Holds references to each player's view model and the ESP manager.
Publishes game metrics (start time, duration, synchronization score) and handles state transitions.
3. UI Structure
ContentView.swift
The main SwiftUI view that switches between different screens based on the current game state.
Screens include: StartScreen, GameScreen, PausedScreen, ResultsScreen.
Also provides a shortcut to show a Metal test view for graphics testing.
StartScreen.swift
The initial screen where players/devices are shown and the game can be started once all are connected.
PlayerCardView.swift & PlayerCardViewModel.swift
UI and logic for displaying individual player/device status.
SingleHeartRateUI.swift
Likely a focused UI for displaying a single heart rate (for testing or single-player mode).
4. Device & Data Management
HeartRateManager.swift
Handles Bluetooth Low Energy (BLE) communication to read heart rate data from peripherals.
Publishes heart rate, connection status, and device info for use in the UI.
ESPPeripheralManager.swift
Manages communication with ESP-based peripherals (likely custom hardware).
SerialManager.swift & SerialDevicePicker.swift
Manage serial device connections and allow the user to pick devices.
OSCManager.swift
Handles Open Sound Control (OSC) messaging, possibly for sending/receiving data to/from other apps or devices.
Persistence.swift
Manages data persistence, likely using Core Data (see the .xcdatamodeld file).
5. Graphics & Visuals
BasicMetalView.swift, MetalTestView.swift, MetalShaderView.swift
Views for rendering custom graphics using Metal (Apple's graphics API).
Used for visual feedback, possibly for breathing or heart rate visualization.
BasicShader.metal, ResonanceShaders.metal
Metal shader files for custom GPU-accelerated graphics.
EnhancedBreathingCircle.swift, WaveformBreathingCircle.swift
Custom SwiftUI views for animated breathing/visualization effects.
6. Other Supporting Files
AppDelegate.swift
Handles app lifecycle events and cleanup.
info.plist, .entitlements
Standard iOS/macOS configuration files.
Assets.xcassets
Contains images and color assets for the UI.
How it fits together
The app is structured around a game/experience where multiple players/devices connect (via BLE or serial), and their heart rates are monitored and visualized.
The GameStateManager coordinates the flow, while each player/device has its own view model and UI card.
Data is visualized using custom Metal graphics and SwiftUI views.
Communication with hardware is handled via BLE, serial, and possibly OSC for interoperability.
