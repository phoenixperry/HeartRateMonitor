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

        // End any active research logging session
        ResearchLogger.shared.endSession()

        espManager?.disconnectCurrentPeripheral()
        heartRateManager?.discoveredPeripherals.removeAll()
    }
}
