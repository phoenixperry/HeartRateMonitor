//
//  SyncConstellationOverlay.swift
//
//  Reactive overlay that draws thin ink lines connecting the player cards
//  to their grid neighbors (horizontal, vertical, and dashed diagonal)
//  when the group's synchronization score crosses the reveal threshold.
//
//  Lives behind the player grid via ZStack. Card centers are computed from
//  the grid shape (columns × rows) and the overlay's own bounds — the
//  overlay must be sized to match the player grid's frame.
//

import SwiftUI

struct SyncConstellationOverlay: View {
    let synchronization: Double
    let columns: Int
    let rows: Int

    // Same threshold band as the halo so they layer together.
    private let lowerThreshold: Double = 85.0
    private let upperThreshold: Double = 95.0

    var body: some View {
        Canvas { context, size in
            guard columns > 0, rows > 0, size.width > 1, size.height > 1 else { return }
            let cellW = size.width / CGFloat(columns)
            let cellH = size.height / CGFloat(rows)

            // Card centers
            var centers: [[CGPoint]] = []
            for row in 0..<rows {
                var rowCenters: [CGPoint] = []
                for col in 0..<columns {
                    rowCenters.append(CGPoint(
                        x: cellW * (CGFloat(col) + 0.5),
                        y: cellH * (CGFloat(row) + 0.5)
                    ))
                }
                centers.append(rowCenters)
            }

            let solid = GraphicsContext.Shading.color(Palette.ink.opacity(0.40))
            let dashed = GraphicsContext.Shading.color(Palette.ink.opacity(0.30))
            let dashStyle = StrokeStyle(lineWidth: 0.5, dash: [2, 3])

            // Horizontal connections within each row
            for row in 0..<rows {
                for col in 0..<(columns - 1) {
                    var path = Path()
                    path.move(to: centers[row][col])
                    path.addLine(to: centers[row][col + 1])
                    context.stroke(path, with: solid, lineWidth: 0.6)
                }
            }

            // Vertical connections within each column
            for col in 0..<columns {
                for row in 0..<(rows - 1) {
                    var path = Path()
                    path.move(to: centers[row][col])
                    path.addLine(to: centers[row + 1][col])
                    context.stroke(path, with: solid, lineWidth: 0.6)
                }
            }

            // Dashed diagonals between adjacent 2×2 cells
            for row in 0..<(rows - 1) {
                for col in 0..<(columns - 1) {
                    var d1 = Path()
                    d1.move(to: centers[row][col])
                    d1.addLine(to: centers[row + 1][col + 1])
                    context.stroke(d1, with: dashed, style: dashStyle)

                    var d2 = Path()
                    d2.move(to: centers[row][col + 1])
                    d2.addLine(to: centers[row + 1][col])
                    context.stroke(d2, with: dashed, style: dashStyle)
                }
            }
        }
        .opacity(intensity)
        .animation(.easeInOut(duration: 1.6), value: intensity)
        .allowsHitTesting(false)
    }

    private var intensity: Double {
        let t = (synchronization - lowerThreshold) / (upperThreshold - lowerThreshold)
        let clamped = max(0, min(1, t))
        return clamped * clamped * (3 - 2 * clamped)
    }
}
