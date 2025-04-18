//
//  PlayerCardViewModel.swift
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 14/04/2025.
//

import Foundation
import SwiftUI
import CoreBluetooth

class PlayerCardViewModel: ObservableObject, Identifiable {
    let id: Int
    let deviceUUID: UUID

    @Published var isConnected: Bool = false
    @Published var hasStartedPlay: Bool = false
    @Published var heartRate: Int = 0
   
    private let heartRateManager = HeartRateManager()
    let oscManager = NativeOSCManager()
    
    init(id: Int, deviceUUID: UUID) {
        self.id = id
        self.deviceUUID = deviceUUID
        //[weak self] lets the closure update the view model’s state without owning it forever. When onConnect is called, it sets isConnected to true — but only if self is still alive. That avoids memory leaks and makes the callback safe and temporary.
//        heartRateManager.onConnect = { [weak self] in
//            self?.isConnected = true
//        }
//        
//        heartRateManager.onHeartRateUpdate = { [weak self] bpm in
//               self?.heartRate = Int(bpm)
//        }
    }
//    func connect() {
//        heartRateManager.connectToPeripheral(with: deviceUUID)
//   }
    func connect() {
        hasStartedPlay = false
        isConnected = false
        heartRate = 0

        heartRateManager.onConnect = { [weak self] in
            self?.isConnected = true
        }

        heartRateManager.onHeartRateUpdate = { [weak self] bpm in
            guard let self = self else { return }

            self.heartRate = Int(bpm)

            if self.hasStartedPlay {
                self.oscManager.sendBPM(forPlayer: self.id, bpm: bpm)
                // wherever you get new heartRate data:
            }
            print("📡 Sending OSC BPM: \(bpm) to /player/\(self.id)/bpm")
            
            //for wekinator
            //oscManager.sendGroupBPMs([player1HR, player2HR, player3HR])
//            If the BLE device sometimes sends the same BPM multiple times in a row (which it might), and you only want to send when the value changes, you could do:
//            if self.hasStartedPlay && bpm != self.heartRate {
//                self.oscManager.send(bpm, to: "/player/\(self.id)/bpm")
//            }

        }
        heartRateManager.connectToPeripheral(with: deviceUUID)
        // (Optional) Only include this if you add scanning fallback
        /*
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self = self else { return }
            if !self.isConnected {
                print("⏱ Timeout: No connection found. Stopping scan.")
                self.heartRateManager.stopScanning()
            }
        }
        */
    }




    func disconnect() {
        heartRateManager.disconnectCurrentPeripheral()
        isConnected = false
        hasStartedPlay = false
    }

    func startPlay() {
        hasStartedPlay = true
    }

}
