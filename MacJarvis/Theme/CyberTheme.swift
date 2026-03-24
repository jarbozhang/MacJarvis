import SwiftUI

// MARK: - Color Palette
struct CyberTheme {
    static let primary = Color(hex: 0x00FFC2)
    static let secondary = Color(hex: 0xFFABF3)
    static let tertiary = Color(hex: 0xC3F400)

    static let surface = Color(hex: 0x131318)
    static let surfaceContainer = Color(hex: 0x1F1F24)
    static let surfaceContainerHigh = Color(hex: 0x2A292F)
    static let surfaceContainerLow = Color(hex: 0x1B1B20)
    static let surfaceContainerLowest = Color(hex: 0x0E0E13)

    static let onSurface = Color(hex: 0xE4E1E9)
    static let onSurfaceVariant = Color(hex: 0xB9CBC1)
    static let outlineVariant = Color(hex: 0x3A4A43)
    static let red = Color(hex: 0xFF0040)

    static let headlineFontName = "SpaceGrotesk-Bold"
    static let bodyFontName = "SpaceGrotesk-Regular"
    static let labelFontName = "SpaceGrotesk-Medium"
    static let cardSpacing: CGFloat = 8

    static func headlineFont(size: CGFloat) -> Font {
        .custom(headlineFontName, size: size)
    }
    static func bodyFont(size: CGFloat) -> Font {
        .custom(bodyFontName, size: size)
    }
    static func labelFont(size: CGFloat) -> Font {
        .custom(labelFontName, size: size)
    }
    static func monoFont(size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - View Modifiers
struct NeonGlow: ViewModifier {
    var color: Color = CyberTheme.primary
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color = CyberTheme.primary) -> some View {
        modifier(NeonGlow(color: color))
    }
}

// MARK: - Pixel Progress Bar
struct PixelProgressBar: View {
    let value: Double
    let color: Color
    var segments: Int = 10

    var body: some View {
        HStack(spacing: 1) {
            let filledCount = Int(value * Double(segments))
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(i < filledCount ? color : CyberTheme.surfaceContainerLowest.opacity(0.2))
                    .overlay(alignment: .trailing) {
                        if i < filledCount {
                            Rectangle().fill(Color.black.opacity(0.3)).frame(width: 1)
                        }
                    }
            }
        }
        .frame(height: 8)
        .padding(2)
        .background(CyberTheme.surfaceContainerLowest)
        .overlay(Rectangle().stroke(CyberTheme.outlineVariant.opacity(0.2), lineWidth: 1))
    }
}
