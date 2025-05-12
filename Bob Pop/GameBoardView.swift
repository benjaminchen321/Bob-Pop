import SwiftUI

struct GameBoardView: View {
    @ObservedObject var gameGrid: GameGrid
    // Removed particleEmitter from here, ContentView will handle it.

    var body: some View {
        // GeometryReader is used to determine the available space for the grid
        GeometryReader { geometry in
            // Calculate block size based on available geometry and grid dimensions
            let numCols = CGFloat(gameGrid.columns)
            let numRows = CGFloat(gameGrid.rows)
            
            // NOTE: Spacing should ideally be calculated based on available space and block size
            // For simplicity, keeping fixed spacing for now, but this can lead to slight inaccuracies
            // if block size calculation doesn't perfectly account for it.
            let spacing: CGFloat = 1 // Define spacing once
            let totalHorizontalSpacing = (numCols - 1) * spacing
            let totalVerticalSpacing = (numRows - 1) * spacing

            let availableWidth = geometry.size.width - totalHorizontalSpacing
            let availableHeight = geometry.size.height - totalVerticalSpacing

            let blockSizeHorizontal = availableWidth / numCols
            let blockSizeVertical = availableHeight / numRows
            
            // Use the smaller dimension to ensure blocks are square and fit
            let blockSize = min(blockSizeHorizontal, blockSizeVertical)
            let finalBlockSize = max(10, blockSize) // Ensure a minimum block size

            // Use ZStack to allow blocks to be positioned freely for animation
            ZStack {
                // Iterate through all logical grid positions
                ForEach(0..<gameGrid.rows, id: \.self) { rowIndex in
                    ForEach(0..<gameGrid.columns, id: \.self) { colIndex in
                        
                        // Get the block (if any) at this logical grid position
                        let block = gameGrid.blocks[rowIndex][colIndex]

                        if let block = block {
                            // If a block exists at this logical position, draw it
                            
                            // Calculate the position based on the block's *visual* row/col
                            let visualX = CGFloat(block.visualCol) * (finalBlockSize + spacing) + finalBlockSize / 2
                            let visualY = CGFloat(block.visualRow) * (finalBlockSize + spacing) + finalBlockSize / 2

                            // Display a GridCellView for the block
                            GridCellView(block: block,
                                         size: finalBlockSize,
                                         action: {
                                            // Call the blockTapped action on the GameGrid
                                            gameGrid.blockTapped(row: rowIndex, col: colIndex)
                                         })
                            // Position the block view using its visual coordinates
                            // The anchor point is the center of the block (size/2, size/2)
                            .position(x: visualX, y: visualY)
                            // Apply animation based on the block's animation state
                            // The .popping state will trigger a different animation than position changes
                            .animation(block.animationState == .popping ?
                                       .easeOut(duration: 0.3) // Fast fade/scale for pop
                                       :
                                       .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), // Spring for fall
                                       value: block.animationState) // Animate changes to the animationState
                            // Also animate position changes specifically for falling/appearing
                            .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), value: block.visualRow)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), value: block.visualCol)


                        } else {
                            // If no block exists at this logical position, draw the empty cell placeholder
                            // Position the empty cell placeholder at its logical grid position
                             RoundedRectangle(cornerRadius: max(4, finalBlockSize * 0.2))
                                 .fill(Color.black.opacity(0.15)) // Darker, more distinct empty cell
                                 .frame(width: finalBlockSize, height: finalBlockSize) // Set the frame size
                                 .position(x: CGFloat(colIndex) * (finalBlockSize + spacing) + finalBlockSize / 2,
                                           y: CGFloat(rowIndex) * (finalBlockSize + spacing) + finalBlockSize / 2)
                                 .onTapGesture {
                                     // Allow tapping empty cells? Current logic ignores, but could be useful for boosters later.
                                     // gameGrid.blockTapped(row: rowIndex, col: colIndex)
                                 }
                        }
                    }
                }
            }
            // Set the frame of the ZStack to match the GeometryReader
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Center the ZStack within the GeometryReader's space
            // (The .frame above already makes it fill the space, so centering is implicit)
        }
    }
}

/// A single cell view representing a block or an empty space
struct GridCellView: View {
    let block: GameBlock? // The block data (optional for empty)
    let size: CGFloat      // The calculated size for this cell
    let action: () -> Void // The action to perform when the cell is tapped

    var body: some View {
        // We only draw the block if it exists
        if let currentBlock = block {
            // Use ZStack for layering effects (from Work Item 1)
            ZStack {
                // Layer 1: Base shape with darker color and main shadow for depth
                RoundedRectangle(cornerRadius: max(4, size * 0.2))
                    .fill(currentBlock.colorType.color.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: max(1, size * 0.08), x: 0, y: max(1, size * 0.08))

                // Layer 2: Main color surface with a subtle gradient
                RoundedRectangle(cornerRadius: max(3, size * 0.18))
                    .fill(LinearGradient(gradient: Gradient(colors: [currentBlock.colorType.color.opacity(0.95), currentBlock.colorType.color]),
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(max(1, size * 0.05))

                // Layer 3: Highlight/Gloss effect
                RoundedRectangle(cornerRadius: max(3, size * 0.18))
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0)]),
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(max(1, size * 0.05))
                    .blendMode(.screen)

                // Layer 4: Subtle inner border/highlight
                 RoundedRectangle(cornerRadius: max(3, size * 0.18))
                     .stroke(Color.white.opacity(0.4), lineWidth: max(0.5, size * 0.02))
                     .padding(max(1, size * 0.05))

                // Layer 5: Darker inner shadow/border (optional, adds more definition)
                 RoundedRectangle(cornerRadius: max(3, size * 0.18))
                     .stroke(Color.black.opacity(0.2), lineWidth: max(0.5, size * 0.02))
                     .padding(max(1, size * 0.05))

            }
            .frame(width: size, height: size) // Set the frame size
            .onTapGesture(perform: action) // Add tap gesture
            // --- Apply Pop Animation Effects ---
            // Scale down and fade out when in the .popping state
            .scaleEffect(currentBlock.animationState == .popping ? 0.1 : 1.0) // Shrink significantly
            .opacity(currentBlock.animationState == .popping ? 0.0 : 1.0) // Fade out completely
            // The animation modifier in GameBoardView handles *how* these changes are animated.
        }
        // If block is nil, this GridCellView draws nothing.
        // The empty cell placeholder is now drawn directly in GameBoardView's ZStack.
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
