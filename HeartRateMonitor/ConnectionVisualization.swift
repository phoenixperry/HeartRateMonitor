import SwiftUI

struct ConnectionVisualization: View {
    let positions: [CGPoint]
    let syncLevel: Double
    
    var body: some View {
        ZStack {
            // Lines connecting the three shapes
            ForEach(0..<positions.count, id: \.self) { i in
                ForEach((i+1)..<positions.count, id: \.self) { j in
                    Path { path in
                        path.move(to: positions[i])
                        path.addLine(to: positions[j])
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.purple.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: CGFloat(2 + syncLevel * 4)
                    )
                    .opacity(syncLevel)
                }
            }
            
            // Central resonance point
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.8), Color.purple.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: CGFloat(20 + syncLevel * 40), height: CGFloat(20 + syncLevel * 40))
                .position(x: (positions[0].x + positions[1].x + positions[2].x) / 3,
                         y: (positions[0].y + positions[1].y + positions[2].y) / 3)
                .opacity(syncLevel)
        }
    }
}
