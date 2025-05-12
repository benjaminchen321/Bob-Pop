import SwiftUI

/// SwiftUI View to display player's lives, gems, and a button to the store
struct LivesGemsView: View {
    // MARK: - Observed Objects
    @ObservedObject var playerData: PlayerData // Player data to display lives and gems

    // MARK: - Styles
    let bodyFont: Font // Passed font style for body text
    let captionFont: Font // Passed font style for caption text (e.g., timer)
    let buttonFont: Font // Passed font style for button text

    // MARK: - Bindings
    @Binding var showStoreSheet: Bool // Binding to control the visibility of the store sheet

    // MARK: - BODY
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) { // Vertical stack, right-aligned
            // Display Lives with an icon
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").foregroundColor(.red) // Heart icon
                Text("\(playerData.lives) / \(playerData.maxLives)") // Current / Max lives
            }.font(bodyFont.weight(.semibold)) // Use body font, bold weight

            // Display time until next life regenerates (if applicable)
            if playerData.lives < playerData.maxLives, let timeRemaining = playerData.timeUntilNextLife() {
                HStack(spacing: 4) {
                    Image(systemName: "timer").foregroundColor(.blue) // Timer icon
                    Text("Next in: \(formattedTime(timeRemaining))") // Formatted time string
                }.font(captionFont.monospacedDigit()) // Use caption font, monospaced for stable display
            }

            // Display Gems with an icon
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill").foregroundColor(.purple) // Gem icon
                Text("\(playerData.gems)") // Current gem count
            }.font(bodyFont.weight(.semibold)) // Use body font, bold weight
            
            // Button to open the store
            Button(action: { showStoreSheet = true }) {
                Label("Get Gems", systemImage: "cart.fill") // Button with icon and text
                    .font(buttonFont) // Use button font
                    .padding(.vertical, 4) // Smaller vertical padding
                    .padding(.horizontal, 8) // Horizontal padding
                    .background(Capsule().fill(Color.green)) // Capsule shape button with green fill
                    .foregroundColor(.white) // White text color
                    .shadow(radius: 1) // Subtle shadow
            }
            .padding(.top, 5) // Space above the button
        }
        .padding(10) // Inner padding
        .background(Material.thin) // Use material background
        .cornerRadius(10) // Rounded corners
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2) // Subtle shadow
    }
    
    // MARK: - Helpers
    /// Formats a TimeInterval into a "MM:SS" string
    func formattedTime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional // e.g., "01:30"
        formatter.zeroFormattingBehavior = .pad // Pad with leading zeros (e.g., "00:05")
        return formatter.string(from: max(0, interval)) ?? "0:00" // Ensure non-negative and provide default
    }
}

// MARK: - PREVIEW
struct LivesGemsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample PlayerData for preview
        let samplePlayerData = PlayerData()
        samplePlayerData.lives = 3 // Example lives
        samplePlayerData.gems = 150 // Example gems
        // Simulate a time for next life regen
        samplePlayerData.lastLifeRegenTime = Date().addingTimeInterval(-samplePlayerData.lifeRegenInterval / 2) // Halfway regenerated

        return LivesGemsView(playerData: samplePlayerData,
                             bodyFont: .system(.body, design: .rounded).weight(.semibold),
                             captionFont: .system(.caption, design: .rounded),
                             buttonFont: .system(.headline, design: .rounded).weight(.bold),
                             showStoreSheet: .constant(false)) // Pass a constant binding for preview
            .padding()
            .background(Color.gray.opacity(0.2)) // Add background to see bounds
            .previewLayout(.sizeThatFits) // Size the preview to fit the content
    }
}
