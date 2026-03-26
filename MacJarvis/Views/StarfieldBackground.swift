import SwiftUI

// MARK: - Star Data Model

struct Star {
    let position: CGPoint  // normalized 0.0-1.0
    let size: CGFloat      // 1-2pt
    let usesThemeColor: Bool
}

// Pure function for testability
func generateStars(count: Int, seed: UInt64 = 42, themeColorRatio: Double = 0.1) -> [Star] {
    var rng = SeededRNG(seed: seed)
    return (0..<count).map { _ in
        Star(
            position: CGPoint(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng)
            ),
            size: CGFloat.random(in: 1...2, using: &rng),
            usesThemeColor: Double.random(in: 0...1, using: &rng) < themeColorRatio
        )
    }
}

// Simple seeded RNG for deterministic star positions
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - StarfieldBackground View

struct StarfieldBackground: View {
    @Environment(\.theme) var theme
    @State private var twinkleOpacity: Double = 0.4

    private let stars = generateStars(count: 100)

    var body: some View {
        ZStack {
            // Base color
            theme.surface

            // Nebula layer: 3 RadialGradients (behind stars)
            // Top-left: theme.primary
            RadialGradient(
                colors: [theme.primary.opacity(0.30), theme.primary.opacity(0.08), .clear],
                center: UnitPoint(x: 0.2, y: 0.2),
                startRadius: 0,
                endRadius: 400
            )
            .allowsHitTesting(false)

            // Top-right: fixed cyan for warm/cool contrast
            RadialGradient(
                colors: [Color(hex: 0x00E5CC).opacity(0.20), Color(hex: 0x00E5CC).opacity(0.05), .clear],
                center: UnitPoint(x: 0.8, y: 0.3),
                startRadius: 0,
                endRadius: 350
            )
            .allowsHitTesting(false)

            // Bottom: theme.primary subtle
            RadialGradient(
                colors: [theme.primary.opacity(0.15), theme.primary.opacity(0.04), .clear],
                center: UnitPoint(x: 0.5, y: 0.9),
                startRadius: 0,
                endRadius: 400
            )
            .allowsHitTesting(false)

            // Stars layer (on top of nebula)
            Canvas { context, size in
                for star in stars {
                    let x = star.position.x * size.width
                    let y = star.position.y * size.height
                    let r = star.size / 2
                    let rect = CGRect(x: x - r, y: y - r, width: star.size, height: star.size)
                    let color = star.usesThemeColor ? theme.primary : Color.white
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            .opacity(twinkleOpacity)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                twinkleOpacity = 0.7
            }
        }
    }
}
