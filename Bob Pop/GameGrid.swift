import SwiftUI
import Combine

/// Manages the game board state, block logic, level progression, and objectives
class GameGrid: ObservableObject {
    @Published var blocks: [[GameBlock?]] {
        didSet {
            // IMPORTANT: Update the flattened list for the view whenever the 2D array changes.
            // Ensure this happens on the main thread as it will trigger UI updates.
            DispatchQueue.main.async {
                self.activeBlocksForView = self.blocks.flatMap { $0.compactMap { $0 } }
            }
        }
    }
    // NEW: This is what GameBoardView will iterate over.
    @Published var activeBlocksForView: [GameBlock] = []

    // ... (other properties: currentLevel, movesRemaining, etc. - no change)
    @Published var currentLevel: LevelDefinition?
    @Published var movesRemaining: Int = 0
    @Published var objectiveProgress: [ObjectiveType: Int] = [:]
    @Published var levelComplete: Bool = false
    @Published var levelFailed: Bool = false
    @Published var activeBoosters: Set<BoosterType> = []
    // MARK: - Constants
    let columns: Int // Number of columns in the grid
    let rows: Int // Number of rows in the grid

    // MARK: - Private Properties
    private var currentLevelNumber: Int = 1 // The ID of the current level
    // Timer/DispatchWorkItem for managing the delay between pop animation and gravity/refill
    private var popAnimationTimer: DispatchWorkItem?

    // MARK: - Callbacks
    // Callback closure that is called when blocks are successfully popped
    // Provides a list of the popped blocks' original row, col, and color
    var onBlocksPopped: ([(row: Int, col: Int, color: BlockColor)]) -> Void = { _ in }

    // MARK: - Initialization
    init(columns: Int, rows: Int, startLevel: Int = 1) {
        self.columns = columns
        self.rows = rows
        // Initialize the blocks array with nil (empty) values
        self.blocks = Array(repeating: Array(repeating: nil, count: columns), count: rows)
        self.currentLevelNumber = startLevel
        // Load the initial level
        loadLevel(levelId: self.currentLevelNumber, selectedBoosters: []) // Start with no boosters
    }

    // MARK: - Level Management
    /// Loads a specific level by its ID
    func loadLevel(levelId: Int, selectedBoosters: Set<BoosterType>) {
        // Retrieve the level definition
        guard let levelDef = GameLevels.getLevel(id: levelId) else {
            print("Error: Level \(levelId) not found!")
            // In a real game, handle this (e.g., show "all levels complete" screen or loop levels)
            return
        }

        // Reset game state for the new level
        self.currentLevel = levelDef
        self.currentLevelNumber = levelId
        self.movesRemaining = levelDef.maxMoves
        self.levelComplete = false
        self.levelFailed = false
        self.objectiveProgress = [:]
        self.activeBoosters = selectedBoosters // Store selected boosters for this attempt

        // Initialize objective progress to 0 for all objectives in the level
        for objective in levelDef.objectives {
            self.objectiveProgress[objective] = 0
        }

        // Apply booster effects that modify starting conditions (e.g., initial moves)
        if activeBoosters.contains(.extraInitialMoves) {
            self.movesRemaining += 3 // Example: Add 3 extra moves
            print("Booster Applied: +3 Initial Moves. Total moves: \(self.movesRemaining)")
        }
        
        // Initialize the grid with new random blocks
        initializeGrid()

        // Apply booster effects that modify the grid after initialization (e.g., placing a power-up)
        if activeBoosters.contains(.startsWithRocket) {
            // TODO: Implement logic to add a rocket to the board after initialization
            // This would involve finding a suitable spot and replacing a block or adding to an empty spot.
            print("Booster Applied: Start with Rocket (Actual placement TODO)")
        }
        
        // Note: @Published properties automatically notify SwiftUI, so objectWillChange.send() is often not needed here.
    }

    /// Fills the grid with random blocks
    func initializeGrid() {
        // Create a temporary grid to build the initial state
        var initialBlocks = Array(repeating: Array<GameBlock?>(repeating: nil, count: columns), count: rows)

        for r in 0..<rows {
            for c in 0..<columns {
                // Place a random colored block in each cell
                if let randomColor = BlockColor.allCases.randomElement() {
                    // For initial blocks, visual position is the same as logical position
                    initialBlocks[r][c] = GameBlock(colorType: randomColor, row: r, col: c)
                }
            }
        }
        // Assign the new grid to the published property
        self.blocks = initialBlocks
    }

    /// Advances the game to the next level or retries the current one
    func advanceToNextLevel() {
        // Cancel any pending pop animation timer
        popAnimationTimer?.cancel()
        popAnimationTimer = nil

        // Boosters are typically reset for a new level attempt
        let boostersForNextAttempt: Set<BoosterType> = []

        if levelComplete {
            // If level was complete, try to load the next level
            let nextLevelId = currentLevelNumber + 1
            if GameLevels.getLevel(id: nextLevelId) != nil {
                loadLevel(levelId: nextLevelId, selectedBoosters: boostersForNextAttempt)
            } else {
                // If no next level, handle game completion (e.g., show end screen, loop levels)
                print("All levels complete! Restarting from level 1 for now.")
                loadLevel(levelId: 1, selectedBoosters: boostersForNextAttempt) // Example: Loop back to level 1
            }
        } else if levelFailed {
            // If level was failed, retry the current level
            print("Retrying level \(currentLevelNumber).")
            loadLevel(levelId: currentLevelNumber, selectedBoosters: boostersForNextAttempt)
        }
        // If neither complete nor failed (e.g., player just bought extra moves), do nothing here.
    }

    // MARK: - Game Logic
    /// Handles a block tap event at a specific row and column
    func blockTapped(row: Int, col: Int) {
        // ... (initial guards - no change) ...
        guard !levelComplete && !levelFailed, movesRemaining > 0, let tappedBlockOriginal = blocks[row][col] else { return }
        let connectedGroup = findConnectedBlocks(from: tappedBlockOriginal)

        if connectedGroup.count >= 2 {
            movesRemaining -= 1
            var poppedBlockInfo: [(row: Int, col: Int, color: BlockColor)] = []

            // --- 1. Mark blocks for popping (visual change driven by GridCellView) ---
            // Create a mutable copy of the current blocks to modify
            var nextBlocksStateAfterPopMarking = self.blocks
            for blockToPopInfo in connectedGroup {
                var found = false
                for r_idx in 0..<self.rows {
                    if let c_idx = nextBlocksStateAfterPopMarking[r_idx].firstIndex(where: { $0?.id == blockToPopInfo.id }) {
                        if var block = nextBlocksStateAfterPopMarking[r_idx][c_idx] {
                            block.animationState = .popping
                            nextBlocksStateAfterPopMarking[r_idx][c_idx] = block
                            
                            updateObjectiveProgress(forPoppedBlock: block)
                            poppedBlockInfo.append((row: block.row, col: block.col, color: block.colorType))
                            found = true; break
                        }
                    }
                    if found { break }
                }
            }
            // Update the main `blocks` array once with all popping states set.
            // No `withAnimation` here, as the pop is cell-intrinsic.
            self.blocks = nextBlocksStateAfterPopMarking
            if !poppedBlockInfo.isEmpty { onBlocksPopped(poppedBlockInfo) }

            // --- Define Animation Durations/Delays ---
            let popVisualDuration: TimeInterval = 0.05
            let fallSettleEstimate: TimeInterval = 0.35 // Adjusted for potentially faster refill start

            popAnimationTimer?.cancel()

            // --- 2. After pop animation, remove blocks and apply gravity ---
            let postPopWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                self.removePoppedBlocksFromModel() // Updates self.blocks, triggers didSet
                self.applyGravityAndAnimate()      // Updates self.blocks withAnimation, triggers didSet

                // --- 3. After gravity animation, refill top rows ---
                let refillWorkItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.refillTopRowsAndAnimate() // Updates self.blocks withAnimation, triggers didSet
                    self.checkLevelCompletion()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + fallSettleEstimate, execute: refillWorkItem)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + popVisualDuration, execute: postPopWorkItem)
            self.popAnimationTimer = postPopWorkItem
        }
    }
    /// Finds all connected blocks of the same color starting from a given block
    private func findConnectedBlocks(from startBlock: GameBlock) -> Set<GameBlock> {
        var groupToPop = Set<GameBlock>() // Set to store the connected group
        var queue: [GameBlock] = [startBlock] // Queue for Breadth-First Search (BFS)
        var visited = Set<GameBlock>() // Set to keep track of visited blocks
        
        visited.insert(startBlock) // Start by visiting the tapped block

        while !queue.isEmpty {
            let currentBlock = queue.removeFirst()
            
            // Add the current block to the group if it matches the starting color
            // (This check is redundant with current logic but good practice)
            if currentBlock.colorType == startBlock.colorType {
                 groupToPop.insert(currentBlock)
            }

            // Define coordinates of potential neighbors (up, down, left, right)
            let neighborsCoordinates = [
                (currentBlock.row - 1, currentBlock.col), (currentBlock.row + 1, currentBlock.col),
                (currentBlock.row, currentBlock.col - 1), (currentBlock.row, currentBlock.col + 1)
            ]
            
            // Check each neighbor
            for (r, c) in neighborsCoordinates {
                // Ensure neighbor coordinates are within grid bounds
                if r >= 0 && r < rows && c >= 0 && c < columns {
                    // Check if there's a block at the neighbor position,
                    // if it's the same color as the starting block,
                    // and if it hasn't been visited yet.
                    if let neighborBlock = blocks[r][c],
                       neighborBlock.colorType == startBlock.colorType,
                       !visited.contains(neighborBlock) {
                        
                        visited.insert(neighborBlock) // Mark as visited
                        queue.append(neighborBlock) // Add to queue for processing
                    }
                }
            }
        }
        return groupToPop // Return the set of connected blocks
    }

    /// Removes blocks that are marked with the .popping animation state
    private func removePoppedBlocksFromModel() {
        var nextBlocks = self.blocks
        var changed = false
        for r in 0..<rows {
            for c in 0..<columns {
                if let block = nextBlocks[r][c], block.animationState == .popping {
                    nextBlocks[r][c] = nil
                    changed = true
                }
            }
        }
        if changed { self.blocks = nextBlocks } // Triggers didSet for activeBlocksForView
    }


    /// Applies gravity, making blocks fall into empty spaces
    private func applyGravityAndAnimate() {
        var nextBlocksAfterGravity = Array(repeating: Array<GameBlock?>(repeating: nil, count: columns), count: rows)
        var changed = false

        // Iterate through current self.blocks to determine where they fall
        for c in 0..<columns {
            var currentWriteRow = rows - 1
            for r_read in (0..<rows).reversed() {
                if var blockToMove = self.blocks[r_read][c] { // Use self.blocks for reading current state
                    if blockToMove.row != currentWriteRow || blockToMove.visualRow != currentWriteRow {
                        changed = true
                    }
                    blockToMove.row = currentWriteRow         // Update LOGICAL row
                    blockToMove.visualRow = currentWriteRow   // Set TARGET visual row
                    blockToMove.animationState = .falling
                    
                    nextBlocksAfterGravity[currentWriteRow][c] = blockToMove
                    currentWriteRow -= 1
                }
            }
        }

        if changed {
            // The `withAnimation` block tells SwiftUI to animate changes resulting from this state update.
            // The actual animation definition (spring) is in GameBoardView.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) { // MODIFIED
                self.blocks = nextBlocksAfterGravity // Triggers didSet for activeBlocksForView
            }
        } else {
            // If no blocks actually moved, but some might have been removed,
            // ensure activeBlocksForView is consistent if it wasn't updated by removePopped.
            // This case should be covered by removePoppedBlocksFromModel if it made changes.
        }
    }

    /// Fills any remaining empty spaces in the grid from the top with new random blocks
    private func refillTopRowsAndAnimate() {
        var nextBlocksAfterRefill = self.blocks // Start with current state (after gravity)
        var changed = false

        for c in 0..<columns {
            for r_target in 0..<rows {
                if nextBlocksAfterRefill[r_target][c] == nil {
                    if let randomColor = BlockColor.allCases.randomElement() {
                        var newBlock = GameBlock(
                            colorType: randomColor,
                            row: r_target, // Logical target row
                            col: c,
                            currentVisualRow: r_target - rows, // Start visually off-screen
                            state: .appearing
                        )
                        // Set its TARGET visualRow for the animation
                        newBlock.visualRow = r_target
                        
                        nextBlocksAfterRefill[r_target][c] = newBlock
                        changed = true
                    }
                }
            }
        }

        if changed {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) { // MODIFIED
                self.blocks = nextBlocksAfterRefill // Triggers didSet for activeBlocksForView
            }
        }
    }

    /// Updates the progress towards objectives based on a popped block
    private func updateObjectiveProgress(forPoppedBlock poppedBlock: GameBlock) {
        guard let objectives = currentLevel?.objectives else { return } // Get current level objectives
        
        // Check each objective
        for objective in objectives {
            switch objective {
            case .popColor(let requiredColor, let requiredCount):
                // If the popped block's color matches the objective's required color
                if poppedBlock.colorType == requiredColor {
                    let currentCount = objectiveProgress[objective, default: 0] // Get current progress
                    // Increment progress, but not beyond the required count
                    if currentCount < requiredCount { objectiveProgress[objective] = currentCount + 1 }
                }
            // Add cases for other objective types here
            }
        }
    }

    /// Checks if the level is complete (all objectives met) or failed (out of moves)
    private func checkLevelCompletion() {
        guard !levelComplete else { return } // Don't re-evaluate if already complete

        guard let currentObjectives = currentLevel?.objectives else { return }
        var allObjectivesMet = true // Assume all objectives are met initially
        
        // Check if all objectives have reached their required count
        for objective in currentObjectives {
            let progress = objectiveProgress[objective, default: 0]
            switch objective {
            case .popColor(_, let requiredCount):
                if progress < requiredCount {
                    allObjectivesMet = false // If any objective is not met, set flag and break
                    break
                }
            // Add cases for other objective types
            }
            if !allObjectivesMet { break } // Break from outer loop if an unmet objective was found
        }

        // Update level state based on checks
        if allObjectivesMet {
            levelComplete = true // Level is complete
            levelFailed = false // Ensure failed flag is false
            print("Level Complete!")
        } else if movesRemaining <= 0 {
            levelFailed = true // Level is failed (out of moves)
            levelComplete = false // Ensure complete flag is false
            print("Level Failed! Out of moves.")
        }
    }

    // MARK: - Monetization Related Actions
    /// Adds extra moves to the current level attempt (typically purchased)
    func addExtraMoves(_ count: Int) {
        // Only allow adding moves if the level was failed (due to moves)
        guard levelFailed else {
            print("Cannot add extra moves, level not in failed state.")
            return
        }
        movesRemaining += count // Add the specified number of moves
        levelFailed = false // Reset the failed state so the player can continue
        print("\(count) extra moves added. Moves remaining: \(movesRemaining)")
        // No need to call checkLevelCompletion here, as player makes the next move.
    }
    
    // MARK: - Deinitialization
    deinit {
        // Cancel the timer when the object is deallocated
        popAnimationTimer?.cancel()
    }
}
