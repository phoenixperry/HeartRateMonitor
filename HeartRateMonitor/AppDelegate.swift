//
//  AppDelegate.swift
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 24/04/2025.
//

import Foundation
import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var espManager:ESPPeripheralManager?
    var heartRateManager:HeartRateManager?
    func applicationWillTerminate(_ notification: Notification) {
        print("App Quitting, disconnecting from ESP")

        // Tear down AU host first so the plugin's audio IO thread stops
        // before AVAudioEngine and the plugin's allocations are freed by
        // dyld unload. Without this, MiniFreak V crashes on quit reading
        // freed memory from its render loop.
        AUEngine.shared.shutdown()

        // End any active research logging session
        ResearchLogger.shared.endSession()

        espManager?.disconnectCurrentPeripheral()
        heartRateManager?.discoveredPeripherals.removeAll()
    }
}
