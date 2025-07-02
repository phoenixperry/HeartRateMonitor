//
//  PlayerDebugInfo.swift
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 02/07/2025.
//

import SwiftUI

// MARK: - Debug Info
struct PlayerDebugInfo: View {
    let label: String
    let bpm: Int
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
            Text("\(bpm)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(bpm > 0 ? .green : .red)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }
}
