import SwiftUI

/// Enum to represent different types of objectives for a level
enum ObjectiveType: Hashable { // Must be Hashable to be used as a dictionary key
    case popColor(color: BlockColor, count: Int) // Objective: Pop a certain number of blocks of a specific color
    // Add more objective types here as needed (e.g., clearBlockers(count: Int), collectItems(count: Int))
}

/// Struct to define the properties of a single game level
struct LevelDefinition: Identifiable {
    let id: Int // Unique identifier for the level (level number)
    let objectives: [ObjectiveType] // A list of objectives for this level
    let maxMoves: Int // The maximum number of moves allowed for this level
    // We could add grid dimensions here if they vary per level,
    // or specific block layouts, required block types, etc. For now, fixed grid size.
}

/// Provides access to the definitions of all game levels
class GameLevels {
    // Static array containing all level definitions
    static let definitions: [LevelDefinition] = [
        LevelDefinition(id: 1,
                        objectives: [.popColor(color: .blue, count: 10)],
                        maxMoves: 15),
        LevelDefinition(id: 2,
                        objectives: [.popColor(color: .red, count: 12),
                                     .popColor(color: .green, count: 12)],
                        maxMoves: 20),
        LevelDefinition(id: 3,
                        objectives: [.popColor(color: .yellow, count: 25),
                                     .popColor(color: .purple, count: 25)],
                        maxMoves: 30), // Made level 3 a bit harder
        LevelDefinition(id: 4,
                        objectives: [.popColor(color: .blue, count: 15),
                                     .popColor(color: .red, count: 15)],
                        maxMoves: 22),
        LevelDefinition(id: 5,
                        objectives: [.popColor(color: .green, count: 30)],
                        maxMoves: 25),
        // Add more levels up to 10 for the MVP as planned
        // LevelDefinition(id: 6, objectives: [...], maxMoves: ...),
        // ...
        // LevelDefinition(id: 10, objectives: [...], maxMoves: ...),
    ]

    /// Retrieves a level definition by its ID
    /// Returns nil if the level ID is not found
    static func getLevel(id: Int) -> LevelDefinition? {
        return definitions.first { $0.id == id }
    }
}
