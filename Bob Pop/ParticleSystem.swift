import SwiftUI

/// Represents a single particle in the system
struct Particle: Identifiable {
    let id = UUID() // Unique ID for SwiftUI
    var x: CGFloat // Current X position
    var y: CGFloat // Current Y position
    // Make size and speed more varied for an explosion effect
    var size: CGFloat = CGFloat.random(in: 2...6) // Smaller, more numerous particles
    var color: Color // Color of the particle
    var opacity: Double = 1.0 // Current opacity
    var scale: CGFloat = 1.0 // Current scale
    // Give particles more initial velocity in random directions
    var xSpeed: CGFloat = CGFloat.random(in: -10.0...10.0) // Wider horizontal spread
    var ySpeed: CGFloat = CGFloat.random(in: -12.0...0.0) // Stronger initial upward/outward burst
    var rotation: Angle = .degrees(Double.random(in: 0...360)) // Initial rotation
    var angularVelocity: Double = Double.random(in: -20...20) // Faster rotation

    var lifetime: Double = Double.random(in: 0.4...0.9) // Shorter lifetime for quicker burst
    var creationTime: Date = Date() // When the particle was created

    /// Checks if the particle is still alive based on its lifetime and visual properties
    var isAlive: Bool {
        Date().timeIntervalSince(creationTime) < lifetime && opacity > 0 // Check lifetime and opacity
    }
}

/// Manages and updates a collection of particles
class ParticleEmitter: ObservableObject {
    @Published var particles: [Particle] = [] // The list of active particles
    private var timer: Timer? // Timer to update particle positions
    private var lastUpdateTime: Date? // Tracks time between updates for consistent movement

    /// Emits a burst of particles from a given point
    func emit(from point: CGPoint, color: Color, count: Int = 25) { // Increased particle count
        for _ in 0..<count {
            particles.append(Particle(x: point.x, y: point.y, color: color))
        }
        
        pruneParticles() // Clean up dead particles
        // Start the timer if it's not already running
        if timer == nil || !timer!.isValid {
            lastUpdateTime = Date() // Initialize last update time
            startTimer()
        }
    }

    /// Starts the timer to update particle positions and properties
    private func startTimer() {
        timer?.invalidate() // Invalidate any existing timer
        // Schedule a new timer to fire at 60 FPS (approx)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return } // Prevent retain cycles

            let now = Date()
            // Calculate time elapsed since the last update for frame-rate independent movement
            let deltaTime = self.lastUpdateTime.map { now.timeIntervalSince($0) } ?? (1.0/60.0)
            self.lastUpdateTime = now

            var hasActiveParticles = false
            // Iterate through particles to update their state
            for i in self.particles.indices.reversed() { // Iterate backwards for safe removal
                let timeAlive = now.timeIntervalSince(self.particles[i].creationTime)
                let progress = timeAlive / self.particles[i].lifetime

                // Update opacity and scale based on lifetime progress
                // Fade out and shrink towards the end of life
                self.particles[i].opacity = max(0, 1.0 - progress * 2.0) // Fade out faster
                self.particles[i].scale = max(0, 1.0 - CGFloat(progress * 1.5)) // Shrink faster

                if self.particles[i].isAlive {
                    // Apply velocity scaled by deltaTime
                    self.particles[i].x += self.particles[i].xSpeed * CGFloat(deltaTime * 60) // Adjust speed factor
                    self.particles[i].y += self.particles[i].ySpeed * CGFloat(deltaTime * 60)
                    
                    // Apply gravity (pulls particles down) scaled by deltaTime
                     self.particles[i].ySpeed += 0.3 * CGFloat(deltaTime * 60) // Slightly stronger gravity

                    self.particles[i].rotation.degrees += self.particles[i].angularVelocity * deltaTime * 60 // Apply rotation

                    hasActiveParticles = true // Mark that there's at least one active particle
                }
            }
            
            self.pruneParticles() // Remove particles that are no longer alive

            // If no particles are active, stop the timer
            if !hasActiveParticles && self.particles.isEmpty {
                self.timer?.invalidate()
                self.timer = nil
                self.lastUpdateTime = nil
                // print("Particle timer stopped.")
            }
            
            // Notify SwiftUI of changes (needed because Particle is not ObservableObject)
            // This is crucial for the Canvas to redraw.
            self.objectWillChange.send()
        }
        // print("Particle timer started.")
    }
    
    /// Removes particles that are no longer alive from the array
    private func pruneParticles() {
        particles.removeAll { !$0.isAlive }
    }

    /// Invalidates the timer when the emitter is deallocated
    deinit {
        timer?.invalidate()
        // print("ParticleEmitter deinit.")
    }
}
