//
//  PlayerCardViewModel.swift
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 14/04/2025.
//

import Foundation
import SwiftUI
import CoreBluetooth

class PlayerCardViewModel:ObservableObject, Identifiable {
    let id: Int
    @Published var isConnected: Bool = false
    @Published var heartRate: Int?
    
    private let heartRateManager:HeartRateManager
    
    init(id: Int, deviceUUID) {
        self.id = id
        self.deviceUUID = deviceUUID
        self.heartRateManager = HeartRateManager()
        
    }
}
