import SwiftUI

struct GameBoardView: View {
    @ObservedObject var gameGrid: GameGrid

    var body: some View {
        GeometryReader { geometry in
            let numCols = CGFloat(gameGrid.columns)
            let numRows = CGFloat(gameGrid.rows) // Used for block size calculation
            let spacing: CGFloat = 1 // Or your desired spacing
            
            // Calculate block size (ensure this is robust)
            let totalHorizontalSpacing = (numCols - 1) * spacing
            let totalVerticalSpacing = (CGFloat(gameGrid.rows) - 1) * spacing // Use gameGrid.rows
            let availableWidth = geometry.size.width - totalHorizontalSpacing
            let availableHeight = geometry.size.height - totalVerticalSpacing
            let blockSizeHorizontal = availableWidth / numCols
            let blockSizeVertical = availableHeight / CGFloat(gameGrid.rows) // Use gameGrid.rows
            let blockSize = min(blockSizeHorizontal, blockSizeVertical)
            let finalBlockSize = max(10, blockSize) // Ensure a minimum block size

            ZStack {
                // Layer 2: Iterate over the active blocks.
                // Each GridCellView is now identified by the block's ID.
                ForEach(gameGrid.activeBlocksForView) { currentBlock in
                    // Calculate position based on the block's *current visual* row/col
                    let visualX = CGFloat(currentBlock.visualCol) * (finalBlockSize + spacing) + finalBlockSize / 2
                    let visualY = CGFloat(currentBlock.visualRow) * (finalBlockSize + spacing) + finalBlockSize / 2

                    GridCellView(block: currentBlock,
                                 size: finalBlockSize,
                                 action: {
                                    // Tapping uses the block's LOGICAL row/col
                                    gameGrid.blockTapped(row: currentBlock.row, col: currentBlock.col)
                                 })
                    .position(x: visualX, y: visualY)
                    // These .animation modifiers define HOW the position change animates
                    // when `currentBlock.visualRow/Col` changes due to model updates in GameGrid.
                    // The `value` parameter ensures animation only triggers on actual changes to these properties.
                    .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: currentBlock.visualRow) // MODIFIED
                    .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: currentBlock.visualCol) // MODIFIED
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Optional: Clip the ZStack if blocks animating from off-screen should be hidden until they enter the bounds
            // .clipped()
        }
    }
}

/// A single cell view representing a block or an empty space
struct GridCellView: View {
    let block: GameBlock?
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        if let currentBlock = block {
            ZStack {
                // Layer 1: Base shape with main shadow for depth
                RoundedRectangle(cornerRadius: max(4, size * 0.22)) // Slightly more rounding
                    .fill(currentBlock.colorType.color.opacity(0.85)) // Base color, slightly less opaque
                    .shadow(color: .black.opacity(0.4), radius: max(1.5, size * 0.06), x: 0, y: max(1.5, size * 0.1)) // Softer, slightly larger shadow

                // Layer 2: Main color surface with a subtle gradient
                RoundedRectangle(cornerRadius: max(3.5, size * 0.20)) // Inner rounding
                    .fill(LinearGradient(gradient: Gradient(colors: [currentBlock.colorType.color.brighter(by: 0.15), currentBlock.colorType.color.darker(by: 0.1)]), // More distinct gradient
                                         startPoint: .top, endPoint: .bottom))
                    .padding(max(1, size * 0.06)) // Slightly increased padding for bevel effect

                // Layer 3: Top Gloss/Highlight effect
                // A more defined, curved highlight
                Path { path in
                    let padding = max(1.5, size * 0.08)
                    let rect = CGRect(x: padding, y: padding, width: size - 2 * padding, height: size - 2 * padding)
                    let cr = max(3, size * 0.18) // Corner radius for highlight shape

                    path.move(to: CGPoint(x: rect.minX + cr, y: rect.minY))
                    path.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.minY))
                    path.addArc(center: CGPoint(x: rect.maxX - cr, y: rect.minY + cr), radius: cr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.4)) // Highlight covers top 40%
                    path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.45), // Curved bottom edge of highlight
                                      control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.6))
                    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
                    path.addArc(center: CGPoint(x: rect.minX + cr, y: rect.minY + cr), radius: cr, startAngle: .degrees(180), endAngle: .degrees(-90), clockwise: false)
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.65)) // Stronger white highlight
                .blendMode(.overlay) // Overlay can give a nice sheen

                // Layer 4: Subtle inner border/highlight for edge definition
                 RoundedRectangle(cornerRadius: max(3.5, size * 0.20))
                     .stroke(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                             lineWidth: max(0.8, size * 0.025)) // Thinner, gradient stroke
                     .padding(max(1, size * 0.06))

            }
            .frame(width: size, height: size)
            .onTapGesture(perform: action)
            .scaleEffect(currentBlock.animationState == .popping ? 0.1 : 1.0)
            .opacity(currentBlock.animationState == .popping ? 0.0 : 1.0)
            .animation(.easeOut(duration: 0.3), value: currentBlock.animationState == .popping)
        }
    }
}

// Helper extension for Color (place this outside the struct, e.g., at file level or in a Color+Extensions.swift)
extension Color {
    func brighter(by percentage: CGFloat = 0.3) -> Color {
        return self.adjust(by: abs(percentage) )
    }

    func darker(by percentage: CGFloat = 0.3) -> Color {
        return self.adjust(by: -1 * abs(percentage) )
    }

    func adjust(by percentage: CGFloat = 0.3) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return Color(UIColor(red: min(red + percentage, 1.0),
                               green: min(green + percentage, 1.0),
                               blue: min(blue + percentage, 1.0),
                               alpha: alpha))
        }
        return self
    }
}

// MARK: - PREVIEW
struct GameBoardView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview the GameBoardView within a fixed frame
        GameBoardView(gameGrid: GameGrid(columns: 8, rows: 10))
            .frame(width: 300, height: 400)
            .padding()
            .background(Color.gray.opacity(0.2)) // Add a background to see the view bounds
    }
}
