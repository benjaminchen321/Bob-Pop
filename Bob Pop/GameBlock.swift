import SwiftUI

enum BlockColor: CaseIterable, Hashable {
    case red, orange, blue, green, yellow, purple // Added Orange

    var color: Color {
        switch self {
        // Approximate Candy Crush colors based on common palettes
        case .red:    return Color(red: 237/255, green: 42/255, blue: 80/255)   // Vibrant Red
        case .orange: return Color(red: 255/255, green: 130/255, blue: 0/255)   // Bright Orange
        case .blue:   return Color(red: 0/255, green: 135/255, blue: 206/255)  // Sky Blue
        case .green:  return Color(red: 124/255, green: 186/255, blue: 46/255)  // Lime Green
        case .yellow: return Color(red: 255/255, green: 210/255, blue: 0/255)   // Sunny Yellow
        case .purple: return Color(red: 148/255, green: 68/255, blue: 174/255)  // Royal Purple
        }
    }
}

// NEW: Enum for block animation states
enum BlockAnimationState {
    case idle       // Sitting still on the board
    case popping    // Currently animating its removal (explosion/shrink)
    case falling    // Moving downwards to a new position
    case appearing  // Newly created, animating into existence
    // Add more later, like 'matched', 'specialEffect', etc.
}

struct GameBlock: Identifiable, Hashable {
    let id = UUID()
    var colorType: BlockColor
    var row: Int // Current logical row in the grid model (final position after fall)
    var col: Int // Current logical col in the grid model

    // NEW: Properties for animation state and visual position
    var animationState: BlockAnimationState = .idle
    // visualRow/Col represent where the block *should* be drawn.
    // During a fall, visualRow will lag behind row.
    var visualRow: Int // Row for visual presentation
    var visualCol: Int // Col for visual presentation

    // Add a property to track the starting visual position for falling
    var initialVisualRow: Int // Where the block started visually before falling

    init(colorType: BlockColor, row: Int, col: Int, initialVisualRow: Int? = nil) {
        self.colorType = colorType
        self.row = row
        self.col = col
        // If initialVisualRow is provided (e.g., for new blocks), use it.
        // Otherwise, start visual position same as logical position.
        self.visualRow = initialVisualRow ?? row
        self.visualCol = col
        self.initialVisualRow = initialVisualRow ?? row // Store the starting visual row
    }

    // Hashable and Equatable remain the same, based on ID
    // NOTE: Hashable/Equatable should ideally *not* include mutable properties like row/col/visualRow/visualCol
    // if the identity is based solely on `id`. However, for simplicity with `Set` in `findConnectedBlocks`,
    // we'll keep it based on `id` only. If we needed to distinguish blocks by position, this would need rethinking.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: GameBlock, rhs: GameBlock) -> Bool { lhs.id == rhs.id }
}
