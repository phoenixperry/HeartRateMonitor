import SwiftUI

struct HexagonVisualizationGroup: View {
    let player1: PlayerCardViewModel
    let player2: PlayerCardViewModel
    let player3: PlayerCardViewModel
    let syncLevel: Double
    let canvasSize: CGSize
    
    // Positioning for triangle arrangement to match physical tiles
    private var positions: [CGPoint] {
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        let radius = min(canvasSize.width, canvasSize.height) * 0.25
        
        return [
            CGPoint(x: centerX, y: centerY - radius),        // Top
            CGPoint(x: centerX - radius * 0.866, y: centerY + radius * 0.5), // Bottom left
            CGPoint(x: centerX + radius * 0.866, y: centerY + radius * 0.5)  // Bottom right
        ]
    }
    
    var body: some View {
        ZStack {
            // Player 1 (top)
            PulsingSyncShape(
                heartRate: player1.heartRate,
                morphLevel: syncLevel,
                playerColor: .player1
            ) {
                // Use existing method - it already handles threading and "only send on change"
                player1.cycleDidComplete()
            }
            .position(positions[0])
            
            // Player 2 (bottom left)
            PulsingSyncShape(
                heartRate: player2.heartRate,
                morphLevel: syncLevel,
                playerColor: .player2
            ) {
                // Use existing method - it already handles threading and "only send on change"
                player2.cycleDidComplete()
            }
            .position(positions[1])
            
            // Player 3 (bottom right)
            PulsingSyncShape(
                heartRate: player3.heartRate,
                morphLevel: syncLevel,
                playerColor: .player3
            ) {
                // Use existing method - it already handles threading and "only send on change"
                player3.cycleDidComplete()
            }
            .position(positions[2])
            
            // Central connection visualization when highly synced
            if syncLevel > 0.7 {
                ConnectionVisualization(
                    positions: positions,
                    syncLevel: syncLevel
                )
                .opacity(syncLevel)
            }
        }
    }
}
