import SwiftUI
import Combine

/// Manages the game board state, block logic, level progression, and objectives
class GameGrid: ObservableObject {
    // MARK: - Published Properties
    @Published var blocks: [[GameBlock?]] // The 2D array representing the game board
    @Published var currentLevel: LevelDefinition? // The definition of the current level
    @Published var movesRemaining: Int = 0 // Moves left in the current level
    @Published var objectiveProgress: [ObjectiveType: Int] = [:] // Tracks progress towards objectives
    @Published var levelComplete: Bool = false // Flag indicating if the level is complete
    @Published var levelFailed: Bool = false // Flag indicating if the level is failed
    
    // For pre-game boosters (data only for now, no UI to select them yet)
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
        // Ignore taps if the level is already complete or failed
        guard !levelComplete && !levelFailed else {
            print("Level already complete or failed. No action.")
            return
        }
        // Ignore taps if no moves are remaining (should be caught by levelFailed, but as safeguard)
        guard movesRemaining > 0 else {
            print("No moves remaining.")
            // If moves are 0 but levelFailed isn't set, mark as failed and check completion
            if !levelFailed { levelFailed = true; checkLevelCompletion() }
            return
        }
        // Ensure a block exists at the tapped location
        guard let tappedBlock = blocks[row][col] else {
            print("Tapped on an empty space.")
            return
        }

        // Find the group of connected, same-colored blocks
        let connectedGroup = findConnectedBlocks(from: tappedBlock)

        // Only proceed if the group size meets the minimum requirement (2 or more)
        if connectedGroup.count >= 2 {
            movesRemaining -= 1 // Decrement moves only for a valid pop

            var poppedBlockInfo: [(row: Int, col: Int, color: BlockColor)] = []
            
            // --- Trigger Pop Animation State ---
            // Iterate through the blocks in the group and mark them for popping.
            // We need to update the *published* blocks array to trigger the UI change.
            // Find the blocks in the actual `self.blocks` array and update their state.
            for blockInGroup in connectedGroup {
                 if let index = blocks[blockInGroup.row].firstIndex(where: { $0?.id == blockInGroup.id }) {
                     blocks[blockInGroup.row][index]?.animationState = .popping // Set state to popping
                     updateObjectiveProgress(forPoppedBlock: blockInGroup) // Update objectives
                     poppedBlockInfo.append((row: blockInGroup.row, col: blockInGroup.col, color: blockInGroup.colorType)) // Store info for particles
                 }
            }

            // Trigger the callback to notify the UI about the popped blocks (for particles)
            if !poppedBlockInfo.isEmpty {
                onBlocksPopped(poppedBlockInfo)
            }

            // --- Schedule Block Removal and Gravity/Refill ---
            // Cancel any existing timer to avoid multiple sequences running
            popAnimationTimer?.cancel()
            
            // Define the work to be done after the pop animation delay
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.removePoppedBlocks() // Remove blocks marked as popping
                self.applyGravity() // Make blocks fall
                self.refillTopRows() // Fill empty spaces from the top
                // Check completion *after* gravity/refill animations settle visually.
                // A more robust approach might delay this further or tie it to animation completion.
                // For now, we'll check immediately after the grid state is updated.
                self.checkLevelCompletion()
            }
            
            // Schedule the work item after a delay (e.g., 0.4 seconds for pop animation)
            let popAnimationDuration: TimeInterval = 0.4 // Adjust this duration to match your desired pop animation length
            DispatchQueue.main.asyncAfter(deadline: .now() + popAnimationDuration, execute: workItem)
            
            // Store the work item so it can be cancelled if another tap happens quickly
            popAnimationTimer = workItem

        } else {
            print("Group too small to pop (need >= 2).")
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
    private func removePoppedBlocks() {
        // Create a new temporary grid state
        var nextBlocks = self.blocks // Start with the current state

        // Iterate through the grid
        for r in 0..<rows {
            for c in 0..<columns {
                // If a block exists and is marked for popping
                if let block = nextBlocks[r][c], block.animationState == .popping {
                    nextBlocks[r][c] = nil // Remove the block
                }
            }
        }
        // Update the published blocks array
        self.blocks = nextBlocks
        // SwiftUI will now remove the views for these nil blocks.
    }


    /// Applies gravity, making blocks fall into empty spaces
    private func applyGravity() {
        // Create a new temporary grid to build the state after gravity
        var nextBlocks = Array(repeating: Array<GameBlock?>(repeating: nil, count: columns), count: rows)
        
        // Keep track of blocks that moved and their new logical positions
        var movedBlocks: [GameBlock] = []

        // Iterate through each column
        for c in 0..<columns {
            var currentWriteRow = rows - 1 // Start writing from the bottom of the new column
            // Iterate upwards from the bottom of the original column
            for r in (0..<rows).reversed() {
                if let block = blocks[r][c] {
                    // If there's a block, place it in the next available spot in the new grid
                    // The new logical row is `currentWriteRow`
                    var blockToMove = block // Get a mutable copy
                    blockToMove.row = currentWriteRow // Update its logical row
                    blockToMove.col = c // Update its logical col (stays same)
                    // Update the visual position to match the new logical position immediately
                    // This is what SwiftUI will animate *from* the old visual position.
                    blockToMove.visualRow = currentWriteRow
                    blockToMove.visualCol = c
                    blockToMove.animationState = .falling // Mark as falling
                    
                    nextBlocks[currentWriteRow][c] = blockToMove
                    movedBlocks.append(blockToMove) // Keep track of blocks that ended up in the new grid
                    currentWriteRow -= 1 // Move up to the next spot in the new column
                }
            }
        }
        
        // Update the published blocks array
        self.blocks = nextBlocks
        // SwiftUI will now animate the blocks from their old visual positions to their new ones.
    }

    /// Fills any remaining empty spaces in the grid from the top with new random blocks
    private func refillTopRows() {
        // Create a new temporary grid based on the current state (after gravity)
        var nextBlocks = self.blocks // Start with the current state

        // Iterate through each column
        for c in 0..<columns {
            // Iterate downwards from the top of the column
            for r in 0..<rows {
                if nextBlocks[r][c] == nil { // If the current spot is empty
                    // Create a new random block for this spot
                    if let randomColor = BlockColor.allCases.randomElement() {
                        // For new blocks, their logical position is (r, c).
                        // Their *initial visual position* should be *above* the grid (e.g., row - 1 or -2)
                        // so they animate *down* into their final spot.
                        var newBlock = GameBlock(colorType: randomColor, row: r, col: c, initialVisualRow: -1) // Start visually above row 0
                        
                        // Immediately set the visual position to the *final* logical position
                        // SwiftUI will animate from the initialVisualRow (-1) to this final visualRow (r)
                        newBlock.visualRow = r
                        newBlock.visualCol = c // visualCol stays the same
                        newBlock.animationState = .appearing // Mark as appearing/falling

                        nextBlocks[r][c] = newBlock
                    }
                }
            }
        }
        // Update the published blocks array
        self.blocks = nextBlocks
        // SwiftUI will now animate the new blocks falling into place.
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
