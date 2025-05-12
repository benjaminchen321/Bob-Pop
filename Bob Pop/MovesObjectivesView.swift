import SwiftUI

/// SwiftUI View to display the current level, moves remaining, and objectives
struct MovesObjectivesView: View {
    // MARK: - Observed Objects
    @ObservedObject var gameGrid: GameGrid // Game grid data to display level info

    // MARK: - Styles
    let headingFont: Font // Passed font style for headings
    let bodyFont: Font // Passed font style for body text

    // MARK: - BODY
    var body: some View {
        VStack(alignment: .leading, spacing: 4) { // Vertical stack, left-aligned
            if let level = gameGrid.currentLevel { // Ensure a level is loaded
                // Display Level ID
                Text("Level: \(level.id)")
                    .font(headingFont)
                    .foregroundColor(.primary)

                // Display Moves Remaining with an icon
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath") // Icon for moves (e.g., refresh)
                        .foregroundColor(.blue) // Icon color
                    Text("\(gameGrid.movesRemaining)")
                        .font(headingFont.weight(.bold)) // Make moves count prominent
                }
                .padding(.bottom, 4) // Space below moves count

                // Display Objectives
                VStack(alignment: .leading, spacing: 2) { // Vertical stack for objectives list
                    Text("Objectives:").font(bodyFont.weight(.semibold)) // Objectives title
                    // Loop through each objective in the current level
                    ForEach(level.objectives.indices, id: \.self) { index in
                        let objective = level.objectives[index]
                        // Get current progress for this objective
                        let progress = gameGrid.objectiveProgress[objective, default: 0]
                        // Display a single objective view
                        objectiveView(objective: objective, progress: progress)
                    }
                }
            }
        }
        .padding(10) // Inner padding
        .background(Material.thin) // Use material background
        .cornerRadius(10) // Rounded corners
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2) // Subtle shadow
    }

    /// Helper View to display a single objective (e.g., "Pop 10 Blue (5/10)")
    func objectiveView(objective: ObjectiveType, progress: Int) -> some View {
        HStack { // Horizontal stack for objective icon and text
            switch objective {
            case .popColor(let color, let count):
                // Display a colored circle icon
                Circle().fill(color.color).frame(width: 16, height: 16) // Slightly smaller icon
                    .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1)) // Subtle border on icon
                // Display objective progress text
                Text("\(progress)/\(count)") // Show progress only (e.g., "5/10")
                    .font(bodyFont)
                    .foregroundColor(.secondary) // Secondary color for progress text
            }
        }
    }
}

// MARK: - PREVIEW
struct MovesObjectivesView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample GameGrid for preview
        let sampleGameGrid = GameGrid(columns: 8, rows: 10)
        // Manually set up a sample level and progress for preview
        sampleGameGrid.loadLevel(levelId: 1, selectedBoosters: [])
        sampleGameGrid.objectiveProgress[.popColor(color: .blue, count: 10)] = 5 // Example progress

        return MovesObjectivesView(gameGrid: sampleGameGrid,
                                   headingFont: .system(.title2, design: .rounded).weight(.semibold),
                                   bodyFont: .system(.body, design: .rounded))
            .padding()
            .background(Color.gray.opacity(0.2)) // Add background to see bounds
            .previewLayout(.sizeThatFits) // Size the preview to fit the content
    }
}
