//
//  MetalTestView.swift
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 04/05/2025.
//

import SwiftUI

struct MetalTestView: View {
    var body: some View {
        VStack {
            Text("MetalTestView")
                .font(.headline)
                .padding()
            BasicMetalView()
                .frame(width:400, height: 300)
                .cornerRadius(10)
            Text("this is a simple metal rendering")
                .font(.caption)
                .padding()
        }
        .padding()
    }
}
#Preview{
    MetalTestView()
}
