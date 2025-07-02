import SwiftUI

/// A shape that morphs from hexagon to circle based on morphLevel (0.0 = hexagon, 1.0 = circle)
struct MorphingHexagonToCircle: View {
    let morphLevel: CGFloat
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2 * 0.9
            
            Path { path in
                let corners = 6
                for i in 0..<corners {
                    let angle = Angle(degrees: Double(i) * 360.0 / Double(corners)).radians
                    let nextAngle = Angle(degrees: Double(i + 1) * 360.0 / Double(corners)).radians
                    
                    // Corner points
                    let startX = cos(angle)
                    let startY = sin(angle)
                    let endX = cos(nextAngle)
                    let endY = sin(nextAngle)
                    
                    // Midpoint between two corners for control
                    let midX = (startX + endX) / 2
                    let midY = (startY + endY) / 2
                    
                    // Control point pushes outward as morph increases
                    let controlX = midX * (1.0 + (morphLevel * 0.4) * 0.8)
                    let controlY = midY * (1.0 + (morphLevel * 0.4) * 0.8)
                    
                    let startPoint = CGPoint(x: center.x + radius * startX, y: center.y + radius * startY)
                    let endPoint = CGPoint(x: center.x + radius * endX, y: center.y + radius * endY)
                    let controlPoint = CGPoint(x: center.x + radius * controlX, y: center.y + radius * controlY)
                    
                    if i == 0 {
                        path.move(to: startPoint)
                    }
                    path.addQuadCurve(to: endPoint, control: controlPoint)
                }
                path.closeSubpath()
            }
            .fill(color.opacity(0.6))
            .overlay(
                Path { path in
                    let corners = 6
                    for i in 0..<corners {
                        let angle = Angle(degrees: Double(i) * 360.0 / Double(corners)).radians
                        let nextAngle = Angle(degrees: Double(i + 1) * 360.0 / Double(corners)).radians
                        
                        let startX = cos(angle)
                        let startY = sin(angle)
                        let endX = cos(nextAngle)
                        let endY = sin(nextAngle)
                        
                        let midX = (startX + endX) / 2
                        let midY = (startY + endY) / 2
                        
                        let controlX = midX * (1.0 + (morphLevel * 0.4) * 0.8)
                        let controlY = midY * (1.0 + (morphLevel * 0.4) * 0.8)
                        
                        let startPoint = CGPoint(x: center.x + radius * startX, y: center.y + radius * startY)
                        let endPoint = CGPoint(x: center.x + radius * endX, y: center.y + radius * endY)
                        let controlPoint = CGPoint(x: center.x + radius * controlX, y: center.y + radius * controlY)
                        
                        if i == 0 {
                            path.move(to: startPoint)
                        }
                        path.addQuadCurve(to: endPoint, control: controlPoint)
                    }
                    path.closeSubpath()
                }
                .stroke(color, lineWidth: 2)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    VStack {
        MorphingHexagonToCircle(morphLevel: 0.0, color: .red)
            .frame(width: 120, height: 120)
        Text("Hexagon (morphLevel: 0.0)")
        
        MorphingHexagonToCircle(morphLevel: 0.5, color: .blue)
            .frame(width: 120, height: 120)
        Text("Half-morphed (morphLevel: 0.5)")
        
        MorphingHexagonToCircle(morphLevel: 1.0, color: .green)
            .frame(width: 120, height: 120)
        Text("Circle (morphLevel: 1.0)")
    }
    .padding()
}
