import SwiftUI
import Combine

/// Enum to represent different types of boosters available
enum BoosterType: Identifiable, Hashable {
    case startsWithRocket // Example booster: Start level with a Rocket power-up
    case extraInitialMoves // Example booster: Start level with extra moves

    var id: Self { self } // Conformance to Identifiable

    /// The cost of the booster in virtual currency (Gems)
    var gemCost: Int {
        switch self {
        case .startsWithRocket: return 20
        case .extraInitialMoves: return 10
        }
    }

    /// A user-friendly description of the booster
    var description: String {
        switch self {
        case .startsWithRocket: return "Start with Rocket"
        case .extraInitialMoves: return "+3 Starting Moves"
        }
    }
}

/// Manages player-specific data like virtual currency (Gems) and Lives
class PlayerData: ObservableObject {
    // MARK: - Published Properties
    @Published var gems: Int = 25 // Player's current virtual currency balance
    @Published var lives: Int = 5 // Player's current lives count
    @Published var lastLifeRegenTime: Date? = nil // Timestamp of the last life regeneration event

    // MARK: - Constants
    let maxLives: Int = 5 // Maximum number of lives a player can have
    let lifeRegenInterval: TimeInterval = 30 * 60 // Time in seconds for one life to regenerate (30 minutes)
    // For testing, you might want a shorter interval:
    // let lifeRegenInterval: TimeInterval = 1 * 60 // 1 minute for quick testing

    // MARK: - Private Properties
    private var regenTimer: Timer? // Timer for scheduling life regeneration

    // MARK: - Initialization
    init() {
        // In a real app, you would load saved player data here (gems, lives, lastLifeRegenTime).
        // For this MVP without persistence, we start with default values.
        
        // If starting with less than max lives (e.g., first launch after losing a life previously),
        // ensure the regeneration timer starts correctly.
        processInitialLives()
        startLifeRegenerationTimer() // Ensure the timer is running based on current state
    }

    /// Processes the initial state of lives, typically after loading saved data
    private func processInitialLives() {
        // This function would calculate how many lives should have regenerated
        // since the last time the app was active, based on `lastLifeRegenTime`.
        // For simplicity in this MVP, it just ensures `lastLifeRegenTime` is set
        // if lives are below max initially.
        if lives < maxLives && lastLifeRegenTime == nil {
             lastLifeRegenTime = Date() // Assume regen starts now if below max and no time is set
        }
    }

    // MARK: - Gems Management
    /// Adds gems to the player's balance
    func addGems(_ amount: Int) {
        gems += amount
        print("Gems updated: \(gems)")
    }

    /// Attempts to spend gems from the player's balance
    /// Returns true if successful, false if not enough gems
    func spendGems(_ amount: Int) -> Bool {
        if gems >= amount {
            gems -= amount
            print("Gems updated: \(gems)")
            return true
        }
        print("Not enough gems. Current: \(gems), Tried to spend: \(amount)")
        return false
    }

    // MARK: - Lives Management
    /// Decrements the player's life count
    func useLife() {
        if lives > 0 {
            lives -= 1
            print("Life used. Lives remaining: \(lives)")
            // If lives drop below max and regen wasn't active, start tracking time
            if lives < maxLives && lastLifeRegenTime == nil {
                lastLifeRegenTime = Date()
            }
            startLifeRegenerationTimer() // Ensure timer is (re)started if needed
        } else {
            print("Attempted to use life, but no lives remaining.")
        }
    }

    /// Increments the player's life count, up to maxLives
    func addLife() {
        if lives < maxLives {
            lives += 1
            print("Life added. Lives: \(lives)")
            // If lives reach max, stop the regeneration timer and clear the timestamp
            if lives == maxLives {
                lastLifeRegenTime = nil
                regenTimer?.invalidate()
                regenTimer = nil
                print("Lives full. Regen timer stopped.")
            }
        }
    }

    /// Refills lives to max using virtual currency
    /// Returns true if successful (enough gems), false otherwise
    func refillLivesWithGems(cost: Int) -> Bool {
        if spendGems(cost) {
            lives = maxLives
            lastLifeRegenTime = nil
            regenTimer?.invalidate()
            regenTimer = nil
            print("Lives refilled with gems!")
            return true
        }
        print("Not enough gems to refill lives.")
        return false
    }

    /// Starts or restarts the life regeneration timer
    func startLifeRegenerationTimer() {
        regenTimer?.invalidate() // Invalidate any existing timer
        guard lives < maxLives else { // Only start if lives are below max
            print("Lives are full, no regen needed.")
            return
        }

        // Ensure lastLifeRegenTime is set if we are below max lives
        if lastLifeRegenTime == nil {
            print("No lastLifeRegenTime set, setting to now for regen start.")
            lastLifeRegenTime = Date() // This should ideally be the time the last life was lost
        }
        
        guard let validLastRegenTime = lastLifeRegenTime else {
            print("Error: lastLifeRegenTime is nil, cannot start timer.")
            return
        }

        // Calculate how many lives might have regenerated since the last known time (e.g., app launch)
        let timeSinceLastRegen = Date().timeIntervalSince(validLastRegenTime)
        if timeSinceLastRegen >= lifeRegenInterval {
            let livesToRegenerate = Int(floor(timeSinceLastRegen / lifeRegenInterval))
            print("Bulk regenerating \(livesToRegenerate) lives.")
            for _ in 0..<livesToRegenerate {
                if self.lives < self.maxLives {
                    self.addLife() // addLife handles stopping timer if max is reached
                } else {
                    break // Stop if max lives reached during bulk regen
                }
            }
            // Update lastLifeRegenTime to reflect the time after the bulk regeneration
            self.lastLifeRegenTime = validLastRegenTime.addingTimeInterval(Double(livesToRegenerate) * lifeRegenInterval)
        }
        
        // If still not full after potential bulk regen, schedule the next specific regen event
        if self.lives < self.maxLives, let currentLastRegenTime = self.lastLifeRegenTime {
            let elapsedSinceLastActualRegen = Date().timeIntervalSince(currentLastRegenTime)
            let nextRegenIn = lifeRegenInterval - elapsedSinceLastActualRegen.truncatingRemainder(dividingBy: lifeRegenInterval)
            
            // Schedule the timer to fire when the next life is ready
            print("Next life regeneration scheduled in \(formattedTime(nextRegenIn)) seconds.")
            regenTimer = Timer.scheduledTimer(withTimeInterval: nextRegenIn, repeats: false) { [weak self] _ in
                print("Timer fired: Attempting to add life.")
                self?.addLife()
                // If a life was successfully added and we are still not full, update the regen time
                if self?.lives ?? 0 < self?.maxLives ?? 0 {
                     self?.lastLifeRegenTime = Date() // Mark this specific regen time
                }
                self?.startLifeRegenerationTimer() // Reschedule for the next one
            }
        } else if self.lives >= self.maxLives {
             // If lives became full during the check, ensure timer is stopped
             regenTimer?.invalidate()
             self.lastLifeRegenTime = nil
             print("Lives are full after check, regen timer stopped/invalidated.")
        }
    }
    
    /// Calculates the time remaining until the next life regenerates
    /// Returns nil if lives are full or regeneration is not active
    func timeUntilNextLife() -> TimeInterval? {
        guard lives < maxLives, let lastRegen = lastLifeRegenTime else { return nil }
        let elapsed = Date().timeIntervalSince(lastRegen)
        if elapsed >= lifeRegenInterval { // A life should have regenerated already
            return 0 // Indicate a life is ready now
        }
        let remaining = lifeRegenInterval - elapsed
        return remaining > 0 ? remaining : 0 // Return remaining time, or 0 if it's negative (shouldn't happen with timer)
    }

    // MARK: - Helpers
    /// Formats a TimeInterval into a "MM:SS" string (private helper)
    private func formattedTime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional // e.g., "01:30"
        formatter.zeroFormattingBehavior = .pad // Pad with leading zeros (e.g., "00:05")
        return formatter.string(from: max(0, interval)) ?? "0:00" // Ensure non-negative and provide default
    }
    
    // MARK: - Deinitialization
    /// Invalidates the timer when the PlayerData object is deallocated
    deinit {
        regenTimer?.invalidate()
        print("PlayerData deinit, timer invalidated.")
    }
}
