// File: GameBlock.swift
import SwiftUI

enum BlockColor: CaseIterable, Hashable {
    // ... (no changes)
    case red, orange, blue, green, yellow, purple

    var color: Color {
        // ... (no changes)
        switch self {
        case .red:    return Color(red: 237/255, green: 42/255, blue: 80/255)
        case .orange: return Color(red: 255/255, green: 130/255, blue: 0/255)
        case .blue:   return Color(red: 0/255, green: 135/255, blue: 206/255)
        case .green:  return Color(red: 124/255, green: 186/255, blue: 46/255)
        case .yellow: return Color(red: 255/255, green: 210/255, blue: 0/255)
        case .purple: return Color(red: 148/255, green: 68/255, blue: 174/255)
        }
    }
}

enum BlockAnimationState {
    case idle
    case popping
    case falling
    case appearing
}

struct GameBlock: Identifiable, Hashable {
    let id = UUID()
    var colorType: BlockColor
    var row: Int // Current LOGICAL row (final destination after fall/appear)
    var col: Int // Current LOGICAL col

    var animationState: BlockAnimationState = .idle
    var visualRow: Int // Current VISUAL row for rendering. This is what animates.
    var visualCol: Int // Current VISUAL col for rendering.

    // Constructor for blocks already on the board or new blocks with a defined start
    init(colorType: BlockColor, row: Int, col: Int, currentVisualRow: Int, currentVisualCol: Int? = nil, state: BlockAnimationState = .idle) {
        self.colorType = colorType
        self.row = row // Logical target
        self.col = col // Logical target
        self.visualRow = currentVisualRow // Where it is visually right NOW
        self.visualCol = currentVisualCol ?? col // Visual col usually matches logical col
        self.animationState = state
    }

    // Simplified constructor for initial grid setup (visual = logical)
    init(colorType: BlockColor, row: Int, col: Int) {
        self.colorType = colorType
        self.row = row
        self.col = col
        self.visualRow = row // Visual starts at logical
        self.visualCol = col // Visual starts at logical
        self.animationState = .idle
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: GameBlock, rhs: GameBlock) -> Bool { lhs.id == rhs.id }
}
