import SwiftUI

// MARK: - Game Background with Atmospheric Gradients
struct GameBackground: View {
    var body: some View {
        ZStack {
            // Main radial gradient: deep blues in bottom left, purples/maroons in top right
            RadialGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),    // Deep blue center
                    Color(red: 0.15, green: 0.1, blue: 0.3),   // Purple-blue mid
                    Color(red: 0.2, green: 0.05, blue: 0.15),  // Dark purple
                    Color(red: 0.3, green: 0.1, blue: 0.1)     // Dark maroon edges
                ],
                center: UnitPoint(x: 0.2, y: 0.8), // Bottom left bias
                startRadius: 50,
                endRadius: 800
            )
            
            // Overlay gradient for depth - top right to bottom left
            LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.1, blue: 0.15).opacity(0.6), // Maroon top right
                    Color.clear,
                    Color(red: 0.05, green: 0.15, blue: 0.35).opacity(0.4)  // Blue bottom left
                ],
                startPoint: UnitPoint(x: 0.9, y: 0.1),
                endPoint: UnitPoint(x: 0.1, y: 0.9)
            )
            
            // Subtle atmospheric noise/texture
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.02),
                            Color.clear,
                            Color.black.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 600
                    )
                )
        }
    }
}

// MARK: - Individual Player Artwork
struct PlayerArtwork: View {
    let playerColor: PlayerArtColor
    let intensity: Double // 0.0 to 1.0 based on heart rate activity
    let morphLevel: Double // 0.0 to 1.0 for hexagon to circle
    
    var body: some View {
        ZStack {
            // Back lighting aura (red glow behind)
            BackLightingAura(color: playerColor.coreColor, intensity: intensity)
            
            // Main gradient circle/hexagon
            MainPlayerShape(
                playerColor: playerColor,
                morphLevel: morphLevel,
                intensity: intensity
            )
            
            // Environmental lighting effects
            EnvironmentalLighting(intensity: intensity)
        }
    }
}

// MARK: - Back Lighting Aura
struct BackLightingAura: View {
    let color: Color
    let intensity: Double
    
    var body: some View {
        // Soft red aura radiating outward
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.3 * intensity),
                        color.opacity(0.15 * intensity),
                        color.opacity(0.05 * intensity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 60,
                    endRadius: 200
                )
            )
            .scaleEffect(1.5)
            .blur(radius: 8)
    }
}

// MARK: - Main Player Shape with Gradients
struct MainPlayerShape: View {
    let playerColor: PlayerArtColor
    let morphLevel: Double
    let intensity: Double
    
    var body: some View {
        // Use your existing morphing hexagon but with beautiful gradients
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2 * 0.8
            
            ZStack {
                // Main gradient shape
                ArtisticMorphingShape(
                    morphLevel: CGFloat(morphLevel),
                    size: size,
                    center: center,
                    radius: radius
                )
                .fill(
                    RadialGradient(
                        colors: playerColor.gradientColors(intensity: intensity),
                        center: UnitPoint(x: 0.4, y: 0.3), // Slightly off-center for dimension
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                
                // Highlight overlay for dimensional lighting
                ArtisticMorphingShape(
                    morphLevel: CGFloat(morphLevel),
                    size: size,
                    center: center,
                    radius: radius * 0.7
                )
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.3 * intensity),
                            Color.white.opacity(0.1 * intensity),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.2), // Top-left highlight
                        startRadius: 0,
                        endRadius: radius * 0.5
                    )
                )
                .blendMode(.overlay)
                
                // Subtle rim lighting
                ArtisticMorphingShape(
                    morphLevel: CGFloat(morphLevel),
                    size: size,
                    center: center,
                    radius: radius
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            playerColor.rimColor.opacity(0.6 * intensity),
                            playerColor.rimColor.opacity(0.2 * intensity),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Environmental Lighting Effects
struct EnvironmentalLighting: View {
    let intensity: Double
    
    var body: some View {
        ZStack {
            // Bottom left cool blue light
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.2 * intensity),
                            Color.cyan.opacity(0.1 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 100)
                .offset(x: -60, y: 40)
                .blur(radius: 15)
            
            // Top right warm maroon light
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.4, green: 0.1, blue: 0.2).opacity(0.25 * intensity),
                            Color(red: 0.3, green: 0.05, blue: 0.15).opacity(0.1 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100
                    )
                )
                .frame(width: 150, height: 80)
                .offset(x: 50, y: -30)
                .blur(radius: 12)
        }
    }
}

// MARK: - Artistic Morphing Shape (Smoother version with clear hexagon→circle progression)
struct ArtisticMorphingShape: Shape {
    let morphLevel: CGFloat
    let size: CGFloat
    let center: CGPoint
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            let corners = 6
            
            // More dramatic morphing - starts as clear hexagon, ends as perfect circle
            for i in 0..<corners {
                let angle = Double(i) * 360.0 / Double(corners) * .pi / 180
                let nextAngle = Double(i + 1) * 360.0 / Double(corners) * .pi / 180
                
                // Corner points for hexagon
                let startX = cos(angle)
                let startY = sin(angle)
                let endX = cos(nextAngle)
                let endY = sin(nextAngle)
                
                // Midpoint between corners
                let midX = (startX + endX) / 2
                let midY = (startY + endY) / 2
                
                // More aggressive morphing - pushes control points out significantly
                // morphLevel 0.0 = sharp hexagon, morphLevel 1.0 = perfect circle
                let morphFactor = 1.0 + (morphLevel * 0.8) // More dramatic curve
                let controlX = midX * morphFactor
                let controlY = midY * morphFactor
                
                let startPoint = CGPoint(
                    x: center.x + radius * startX,
                    y: center.y + radius * startY
                )
                let endPoint = CGPoint(
                    x: center.x + radius * endX,
                    y: center.y + radius * endY
                )
                let controlPoint = CGPoint(
                    x: center.x + radius * controlX,
                    y: center.y + radius * controlY
                )
                
                if i == 0 {
                    path.move(to: startPoint)
                }
                path.addQuadCurve(to: endPoint, control: controlPoint)
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Player Art Color System
struct PlayerArtColor {
    let coreColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let rimColor: Color
    
    func gradientColors(intensity: Double) -> [Color] {
        let baseIntensity = 0.3 + (intensity * 0.7) // Never completely dim
        
        return [
            coreColor.opacity(baseIntensity),
            secondaryColor.opacity(baseIntensity * 0.8),
            accentColor.opacity(baseIntensity * 0.6),
            rimColor.opacity(baseIntensity * 0.3)
        ]
    }
    
    // Predefined color schemes for each player
    static let player1 = PlayerArtColor(
        coreColor: Color(red: 0.9, green: 0.1, blue: 0.2),     // Vivid red
        secondaryColor: Color(red: 0.8, green: 0.3, blue: 0.6), // Magenta
        accentColor: Color(red: 0.6, green: 0.2, blue: 0.8),    // Purple
        rimColor: Color(red: 0.3, green: 0.4, blue: 0.9)        // Blue edge
    )
    
    static let player2 = PlayerArtColor(
        coreColor: Color(red: 0.2, green: 0.6, blue: 0.9),     // Bright blue
        secondaryColor: Color(red: 0.4, green: 0.3, blue: 0.8), // Blue-purple
        accentColor: Color(red: 0.6, green: 0.2, blue: 0.7),    // Purple
        rimColor: Color(red: 0.8, green: 0.1, blue: 0.4)        // Magenta edge
    )
    
    static let player3 = PlayerArtColor(
        coreColor: Color(red: 0.9, green: 0.7, blue: 0.1),     // Golden yellow
        secondaryColor: Color(red: 0.9, green: 0.4, blue: 0.2), // Orange
        accentColor: Color(red: 0.8, green: 0.3, blue: 0.6),    // Pink-purple
        rimColor: Color(red: 0.4, green: 0.2, blue: 0.8)        // Purple edge
    )
}

#Preview {
    ZStack {
        GameBackground()
        
        VStack(spacing: 40) {
            // Show morphing progression
            HStack(spacing: 40) {
                VStack {
                    PlayerArtwork(
                        playerColor: .player1,
                        intensity: 0.8,
                        morphLevel: 0.0  // Pure hexagon
                    )
                    .frame(width: 120, height: 120)
                    Text("Hexagon (0% sync)")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                VStack {
                    PlayerArtwork(
                        playerColor: .player1,
                        intensity: 0.8,
                        morphLevel: 0.5  // Half morphed
                    )
                    .frame(width: 150, height: 150) // Larger as it syncs
                    Text("Morphing (50% sync)")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                VStack {
                    PlayerArtwork(
                        playerColor: .player1,
                        intensity: 0.8,
                        morphLevel: 1.0  // Perfect circle
                    )
                    .frame(width: 180, height: 180) // Largest when fully synced
                    Text("Circle (100% sync)")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            
            // Show overlapping effect when all three are synced
            Text("Fully Synchronized State:")
                .foregroundColor(.white)
                .font(.headline)
            
            ZStack {
                // Simulate three overlapping circles
                PlayerArtwork(
                    playerColor: .player1,
                    intensity: 0.9,
                    morphLevel: 1.0
                )
                .frame(width: 180, height: 180)
                .offset(x: -30, y: -20)
                
                PlayerArtwork(
                    playerColor: .player2,
                    intensity: 0.9,
                    morphLevel: 1.0
                )
                .frame(width: 180, height: 180)
                .offset(x: 30, y: -20)
                
                PlayerArtwork(
                    playerColor: .player3,
                    intensity: 0.9,
                    morphLevel: 1.0
                )
                .frame(width: 180, height: 180)
                .offset(x: 0, y: 25)
            }
            .blendMode(.screen) // Makes overlaps blend beautifully
        }
    }
    .frame(width: 1000, height: 800)
}
