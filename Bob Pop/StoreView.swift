import SwiftUI

/// Represents a single package available for purchase in the store
struct StorePackage: Identifiable {
    let id = UUID() // Unique ID
    let gemAmount: Int // Number of gems in the package
    let priceString: String // Display string for the price (e.g., "$0.99")
    let description: String // Description of the package
}

/// Sample store packages (using simulated prices)
let storePackages: [StorePackage] = [
    StorePackage(gemAmount: 50, priceString: "$0.99 (Sim)", description: "Starter Pack"),
    StorePackage(gemAmount: 300, priceString: "$4.99 (Sim)", description: "Value Pack"),
    StorePackage(gemAmount: 1000, priceString: "$9.99 (Sim)", description: "Big Gem Pack"),
    StorePackage(gemAmount: 2500, priceString: "$19.99 (Sim)", description: "Super Gem Pack")
]

/// SwiftUI View for displaying the in-game store
struct StoreView: View {
    // MARK: - Observed Objects
    @ObservedObject var playerData: PlayerData // Player's data to update gems

    // MARK: - Environment
    @Environment(\.dismiss) var dismiss // Environment value to dismiss the sheet

    // MARK: - Styles
    // Using consistent font styles
    let titleFont = Font.system(.largeTitle, design: .rounded).weight(.bold)
    let headingFont = Font.system(.title2, design: .rounded).weight(.semibold)
    let bodyFont = Font.system(.body, design: .rounded)
    let buttonFont = Font.system(.headline, design: .rounded).weight(.bold)

    // MARK: - BODY
    var body: some View {
        // Use NavigationView for a title bar and close button
        NavigationView {
            VStack(spacing: 15) { // Vertical stack for layout
                Text("Gem Store")
                    .font(titleFont.weight(.medium)) // Slightly less bold for sheet title
                    .padding(.bottom)

                // Display current gem balance
                Text("Current Gems: \(playerData.gems)")
                    .font(headingFont)
                    .padding(.bottom)

                // Scrollable list of store packages
                ScrollView {
                    VStack(spacing: 15) { // Vertical stack for packages
                        ForEach(storePackages) { package in
                            HStack { // Horizontal stack for package details and button
                                VStack(alignment: .leading) { // Package name and description
                                    Text("\(package.gemAmount) Gems")
                                        .font(headingFont.weight(.regular))
                                    Text(package.description)
                                        .font(bodyFont.weight(.light))
                                        .foregroundColor(.secondary)
                                }
                                Spacer() // Pushes button to the right
                                
                                // Button to "purchase" the package (simulated)
                                Button(action: {
                                    // Simulate purchase - NO REAL IAP YET
                                    playerData.addGems(package.gemAmount) // Add gems to player data
                                    print("Simulated purchase of \(package.gemAmount) gems for \(package.priceString).")
                                    // In a real app, this would trigger StoreKit purchase flow.
                                    // You might want to dismiss the store after a successful "purchase".
                                    // dismiss()
                                }) {
                                    Text(package.priceString)
                                        .font(buttonFont.weight(.regular))
                                        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                        .foregroundColor(.white)
                                        .background(Capsule().fill(Color.blue)) // Capsule shape button
                                }
                            }
                            .padding() // Padding inside the package row
                            .background(Material.thin) // Use Material background for rows
                            .cornerRadius(15) // Rounded corners for rows
                        }
                    }
                }
                Spacer() // Pushes content up if ScrollView doesn't fill space
            }
            .padding() // Padding around the main VStack content
            .navigationTitle("Store") // Title for the navigation bar
            .navigationBarTitleDisplayMode(.inline) // Display title inline
            .toolbar { // Add toolbar items
                ToolbarItem(placement: .navigationBarTrailing) { // Place item on the right
                    Button("Close") { // Close button
                        dismiss() // Dismiss the sheet
                    }
                    .font(bodyFont) // Use body font for the close button
                }
            }
            // Background for the entire sheet content area
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
    }
}

// MARK: - PREVIEW
struct StoreView_Previews: PreviewProvider {
    static var previews: some View {
        StoreView(playerData: PlayerData()) // Preview the StoreView with sample player data
    }
}
