import SwiftUI

struct ContentView: View {
    // MARK: - STATE
    @StateObject private var gameGrid = GameGrid(columns: 8, rows: 10)
    @StateObject private var playerData = PlayerData()
    @StateObject private var particleEmitter = ParticleEmitter() // Owns the emitter

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // State for UI
    @State private var showOutOfLivesPrompt: Bool = false
    @State private var showStoreSheet: Bool = false
    @State private var showExtraMovesPrompt: Bool = false
    
    // State for Layout
    @State private var gameBoardFrame: CGRect = .zero // To get GameBoardView's frame for particles

    // MARK: - CONSTANTS
     let refillLivesCost = 10
     let extraMovesCost = 15
     let extraMovesAmount = 5
    
    // MARK: - STYLES
     // Using system fonts with rounded design for a consistent look
     let titleFont = Font.system(.largeTitle, design: .rounded).weight(.bold)
     let headingFont = Font.system(.title2, design: .rounded).weight(.semibold)
     let bodyFont = Font.system(.body, design: .rounded)
     let buttonFont = Font.system(.headline, design: .rounded).weight(.bold)
     let captionFont = Font.system(.caption, design: .rounded)

    // MARK: - BODY
    var body: some View {
        // Main ZStack for layering elements: background, game board, UI, particles, overlays
        ZStack {
            // --- BACKGROUND ---
            // Apply a subtle gradient background to the entire view
            LinearGradient(gradient: Gradient(colors: [
                 Color(UIColor.systemBackground), // Use system colors to adapt to light/dark mode
                 Color.blue.opacity(0.2),
                 Color.purple.opacity(0.2)
            ]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)

            // --- GAME BOARD CONTAINER ---
            // This view contains the actual GameBoardView and handles its background/aspect ratio
            gameBoardContainer

            // --- OVERLAID UI ELEMENTS ---
            // Position UI elements around the edges using a combination of Stacks and Spacers
            VStack { // Top-level VStack to align elements vertically
                HStack { // HStack for elements on the top-left and top-right
                    MovesObjectivesView(gameGrid: gameGrid, headingFont: headingFont, bodyFont: bodyFont)
                        .padding(.leading) // Padding from the left safe area
                        .padding(.top)    // Padding from the top safe area
                    
                    Spacer() // Pushes the Moves/Objectives view to the left

                    LivesGemsView(playerData: playerData, bodyFont: bodyFont, captionFont: captionFont, buttonFont: buttonFont, showStoreSheet: $showStoreSheet)
                        .padding(.trailing) // Padding from the right safe area
                        .padding(.top)     // Padding from the top safe area
                }
                
                Spacer() // Pushes the entire top HStack to the top of the ZStack
                
                // Add other potential UI elements here, e.g., a pause button at the bottom
                // Example:
                // Button(action: { /* Pause action */ }) {
                //     Image(systemName: "pause.circle.fill")
                //         .resizable()
                //         .scaledToFit()
                //         .frame(width: 40, height: 40)
                //         .foregroundColor(.white)
                //         .shadow(radius: 2)
                // }
                // .padding(.bottom) // Padding from the bottom safe area
            }
            // The VStack/HStack structure is a starting point.
            // More complex layouts might need explicit positioning with .offset or .position
            // or using AlignmentGuides. For now, this top-aligned HStack is simple.


            // --- PARTICLE EFFECT CANVAS ---
             // This Canvas draws particles on top of all other content
             Canvas { context, size in
                 context.blendMode = .screen // Optional: For additive, brighter particles
                 for particle in particleEmitter.particles {
                     if particle.isAlive {
                         var particleContext = context
                         particleContext.opacity = particle.opacity
                         
                         let rect = CGRect(x: particle.x - (particle.size * particle.scale / 2),
                                           y: particle.y - (particle.size * particle.scale / 2),
                                           width: particle.size * particle.scale,
                                           height: particle.size * particle.scale)
                        
                         // Rotate the particle around its center
                         let center = CGPoint(x: rect.midX, y: rect.midY)
                         var transform = CGAffineTransform.identity
                         transform = transform.translatedBy(x: center.x, y: center.y)
                         transform = transform.rotated(by: CGFloat(particle.rotation.radians))
                         transform = transform.translatedBy(x: -center.x, y: -center.y)
                        
                         // Draw as a Circle (simpler, often effective for sparks)
                         let path = Path(ellipseIn: rect) // Changed from RoundedRectangle
                         particleContext.fill(path.applying(transform), // Keep transform for rotation
                                              with: .radialGradient(Gradient(colors: [particle.color.opacity(particle.opacity * 0.8), // Core color
                                                                                      particle.color.opacity(particle.opacity * 0.5), // Mid fade
                                                                                      Color.white.opacity(particle.opacity * 0.3),   // Outer glow (whiteish)
                                                                                      Color.clear]),
                                                                    center: center,
                                                                    startRadius: 0,
                                                                    endRadius: rect.width / 1.5)) // Adjust gradient spread
                     }
                 }
             }
             .blendMode(.plusLighter) // Try .plusLighter for very bright, additive particles (or keep .screen)
             .allowsHitTesting(false) // Particles should not block interaction
             .edgesIgnoringSafeArea(.all) // Draw anywhere, including safe areas

            // --- OVERLAYS / SHEETS (These are already full-screen overlays) ---
            // These views appear on top of everything else when their state variables are true
            levelEndOverlay
            extraMovesOverlay
            outOfLivesOverlay
            // The .sheet modifier is applied to the main ZStack or ContentView
        }
        // Apply the sheet modifier to the top-level view
        .sheet(isPresented: $showStoreSheet) {
            StoreView(playerData: playerData) // Present the StoreView as a sheet
        }
        // --- EVENT HANDLING ---
        .onAppear {
            setupCallbacks() // Setup gameGrid callbacks when the view appears
            playerData.startLifeRegenerationTimer() // Start the life regeneration timer
        }
        .onChange(of: gameGrid.levelFailed) { failed in
             // Trigger "Extra Moves" prompt ONLY if failure was due to running out of moves.
            if failed && gameGrid.movesRemaining <= 0 {
                showExtraMovesPrompt = true
            }
         }
    }
     
    // MARK: - SETUP
    /// Sets up callbacks from the GameGrid model to trigger UI effects
    func setupCallbacks() {
       // Setup the callback for when blocks are popped
       gameGrid.onBlocksPopped = { infos in
           // Ensure we have the game board's frame to calculate particle positions
           guard gameBoardFrame != .zero else {
              // print("Warning: gameBoardFrame not set, cannot emit particles accurately.")
               return
           }

           // Calculate the size of a single block based on the board's frame and grid dimensions
           let singleBlockWidth = gameBoardFrame.width / CGFloat(gameGrid.columns)
           let singleBlockHeight = gameBoardFrame.height / CGFloat(gameGrid.rows)

           // Emit particles for each block that was popped
           for info in infos {
               // Calculate the center of the block in global coordinates
               let particleX = gameBoardFrame.origin.x + (CGFloat(info.col) * singleBlockWidth) + (singleBlockWidth / 2)
               let particleY = gameBoardFrame.origin.y + (CGFloat(info.row) * singleBlockHeight) + (singleBlockHeight / 2)
               
               // Tell the particle emitter to create particles at this location
               particleEmitter.emit(from: CGPoint(x: particleX, y: particleY), color: info.color.color, count: 6)
           }
       }
    }

    // MARK: - SUBVIEWS
    
    /// Container that holds the GameBoardView and applies background/aspect ratio
    /// Also uses GeometryReader to capture the board's frame for particle positioning
    var gameBoardContainer: some View {
        ZStack {
             // Background for the game board area
             // NOTE: .material requires iOS 15+. Fallback for < iOS 15: .background(Color(UIColor.systemBackground).opacity(0.7))
            RoundedRectangle(cornerRadius: 12)
                 .fill(Material.ultraThinMaterial) // Use a modern material effect
                 .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4) // Subtle shadow

            // The actual GameBoardView displaying the blocks
            GameBoardView(gameGrid: gameGrid)
                // Padding inside the material background, around the grid itself
                .padding(12)
                // Use GeometryReader to capture the frame of the GameBoardView's allocated space
                .background(
                    GeometryReader { geo in
                        Color.clear // Invisible view
                            .onAppear { self.gameBoardFrame = geo.frame(in: .global) } // Capture frame on appear
                            .onChange(of: geo.frame(in: .global)) { newFrame in // Update frame if layout changes
                                self.gameBoardFrame = newFrame
                            }
                     }
                )
        }
        // Apply the aspect ratio to the container, allowing it to scale while maintaining shape
        .aspectRatio(CGFloat(gameGrid.columns) / CGFloat(gameGrid.rows), contentMode: .fit)
        // Allow the container to take up as much space as possible within its parent ZStack
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // No vertical padding here, ZStack handles centering
    }

    // MARK: - OVERLAY VIEWS

    /// Overlay displayed when the level is completed
    @ViewBuilder
    var levelEndOverlay: some View {
        if gameGrid.levelComplete {
            promptOverlay(title: "Level Complete!",
                          primaryButtonText: "Next Level",
                          primaryButtonColor: .green,
                          primaryAction: {
                             gameGrid.advanceToNextLevel() // Load the next level
                          })
        }
    }

    /// Overlay displayed when the player runs out of moves, offering extra moves
    @ViewBuilder
    var extraMovesOverlay: some View {
        if showExtraMovesPrompt {
            promptOverlay(title: "Out of Moves!",
                          message: "Get +\(extraMovesAmount) moves to continue?",
                          primaryButtonText: "Get +\(extraMovesAmount) Moves (\(extraMovesCost) Gems)",
                          primaryButtonColor: .orange,
                          primaryAction: {
                              if playerData.spendGems(extraMovesCost) {
                                  gameGrid.addExtraMoves(extraMovesAmount) // Add moves to game grid
                                  showExtraMovesPrompt = false // Close this prompt
                              } else {
                                  showExtraMovesPrompt = false // Close this prompt
                                  showStoreSheet = true      // Open the store if not enough gems
                              }
                          },
                          secondaryButtonText: "No Thanks",
                          secondaryAction: {
                              showExtraMovesPrompt = false // Close this prompt
                              playerData.useLife() // Use a life if declining extra moves
                              if playerData.lives > 0 {
                                  gameGrid.advanceToNextLevel() // Retry the level
                              } else {
                                  showOutOfLivesPrompt = true // Show the "Out of Lives" prompt if no lives left
                              }
                          })
        }
    }
    
    // Helper computed property for the Out of Lives message (moved outside ViewBuilder)
    var outOfLivesMessage: String {
        if playerData.lives < playerData.maxLives, let timeRemaining = playerData.timeUntilNextLife() {
            return "Next life in: \(formattedTime(timeRemaining))"
        } else {
            return "Wait for a life or refill."
        }
    }

    /// Overlay displayed when the player runs out of lives
    @ViewBuilder
    var outOfLivesOverlay: some View {
        if showOutOfLivesPrompt {
            promptOverlay(title: "Out of Lives!",
                          message: outOfLivesMessage, // Use the helper property here
                          primaryButtonText: "Refill Lives (\(refillLivesCost) Gems)",
                          primaryButtonColor: .blue, // Use a different color than extra moves
                          primaryAction: {
                              if playerData.refillLivesWithGems(cost: refillLivesCost) {
                                  showOutOfLivesPrompt = false // Close this prompt
                                  gameGrid.advanceToNextLevel() // Retry the level
                              } else {
                                  showOutOfLivesPrompt = false // Close this prompt
                                  showStoreSheet = true // Open the store if not enough gems
                              }
                          },
                          secondaryButtonText: "Close",
                          secondaryAction: {
                              showOutOfLivesPrompt = false // Close this prompt
                          })
        }
    }
    
    /// Reusable View Builder function for standard prompt overlays
    @ViewBuilder
    func promptOverlay(title: String, message: String? = nil, primaryButtonText: String, primaryButtonColor: Color, primaryAction: @escaping () -> Void, secondaryButtonText: String? = nil, secondaryAction: (() -> Void)? = nil) -> some View {
       
        VStack(spacing: 15) {
            Text(title)
                .font(headingFont) // Use heading font for prompt titles
                .foregroundColor(.primary)

            if let msg = message {
                Text(msg)
                    .font(bodyFont)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Primary Button
            Button(action: primaryAction) {
                Text(primaryButtonText)
                    .font(buttonFont)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(primaryButtonColor)) // Capsule shape button
                    .foregroundColor(.white)
                     .shadow(color: primaryButtonColor.opacity(0.4), radius: 3, y: 2) // Button shadow
            }

            // Secondary Button (Optional)
            if let secText = secondaryButtonText, let secAction = secondaryAction {
                Button(action: secAction) {
                    Text(secText)
                        .font(bodyFont.weight(.medium)) // Less prominent than primary
                }
                .padding(.top, 5)
                 .tint(.secondary) // Use system tint for secondary actions
            }
        }
        .padding(EdgeInsets(top: 25, leading: 25, bottom: 20, trailing: 25)) // Inner padding
        .frame(maxWidth: 380) // Max width for the prompt box
        // Background for the prompt box itself
        // NOTE: .regularMaterial requires iOS 15+. Fallback for < iOS 15: .background(Color(UIColor.secondarySystemBackground))
        .background(Material.regularMaterial)
        .cornerRadius(20) // Rounded corners for the prompt box
        .shadow(color: .black.opacity(0.3), radius: 10, x:0, y:5) // Shadow for the prompt box
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Frame to make the backdrop fill the screen
        .background(Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)) // Semi-transparent backdrop
        .transition(.opacity.combined(with: .scale(scale: 0.9))) // Add a transition effect when it appears/disappears
    }
    
    // MARK: - HELPERS
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
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 13 Pro") // Preview on iPhone
        
         ContentView()
            .previewDevice("iPad Pro (11-inch) (3rd generation)") // Preview on iPad
            .previewInterfaceOrientation(.landscapeLeft) // Preview in landscape
            .preferredColorScheme(.dark) // Test dark mode preview
    }
}
