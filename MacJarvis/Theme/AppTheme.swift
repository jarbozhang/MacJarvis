import SwiftUI

// MARK: - Theme Enum
enum AppTheme: String, CaseIterable {
    case redact = "redact"
    case matrix = "matrix"

    // MARK: Colors
    var primary: Color {
        switch self {
        case .redact: Color(hex: 0xFF8E80)
        case .matrix: Color(hex: 0x00FFC2)
        }
    }
    var primaryDim: Color {
        switch self {
        case .redact: Color(hex: 0xE2241F)
        case .matrix: Color(hex: 0x00B88A)
        }
    }
    var secondary: Color {
        switch self {
        case .redact: Color(hex: 0xFE7E4F)
        case .matrix: Color(hex: 0xFFABF3)
        }
    }
    var tertiary: Color {
        switch self {
        case .redact: Color(hex: 0xFFE792)
        case .matrix: Color(hex: 0xC3F400)
        }
    }

    var surface: Color {
        switch self {
        case .redact: Color(hex: 0x0E0E0E)
        case .matrix: Color(hex: 0x131318)
        }
    }
    var surfaceContainer: Color {
        switch self {
        case .redact: Color(hex: 0x1A1919)
        case .matrix: Color(hex: 0x1F1F24)
        }
    }
    var surfaceContainerHigh: Color {
        switch self {
        case .redact: Color(hex: 0x201F1F)
        case .matrix: Color(hex: 0x2A292F)
        }
    }
    var surfaceContainerLow: Color {
        switch self {
        case .redact: Color(hex: 0x131313)
        case .matrix: Color(hex: 0x1B1B20)
        }
    }
    var surfaceContainerLowest: Color {
        switch self {
        case .redact: Color(hex: 0x000000)
        case .matrix: Color(hex: 0x0E0E13)
        }
    }

    var onSurface: Color {
        switch self {
        case .redact: Color(hex: 0xFFFFFF)
        case .matrix: Color(hex: 0xE4E1E9)
        }
    }
    var onSurfaceVariant: Color {
        switch self {
        case .redact: Color(hex: 0xADAAAA)
        case .matrix: Color(hex: 0xB9CBC1)
        }
    }
    var outlineVariant: Color {
        switch self {
        case .redact: Color(hex: 0x484847)
        case .matrix: Color(hex: 0x3A4A43)
        }
    }

    var error: Color {
        switch self {
        case .redact: Color(hex: 0xFF6E84)
        case .matrix: Color(hex: 0xFF0040)
        }
    }
    var errorContainer: Color {
        switch self {
        case .redact: Color(hex: 0xA70138)
        case .matrix: Color(hex: 0xFF0040)
        }
    }

    // MARK: Fonts (theme-independent)
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

// MARK: - Environment Keys
struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .redact
}

struct ScaleFactorKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
    var scaleFactor: CGFloat {
        get { self[ScaleFactorKey.self] }
        set { self[ScaleFactorKey.self] = newValue }
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
