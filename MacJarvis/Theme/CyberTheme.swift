import SwiftUI

// MARK: - View Modifiers
struct NeonGlow: ViewModifier {
    var color: Color
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color) -> some View {
        modifier(NeonGlow(color: color))
    }
}

// MARK: - Pixel Progress Bar
struct PixelProgressBar: View {
    @Environment(\.theme) var theme
    let value: Double
    let color: Color
    var segments: Int = 10

    var body: some View {
        HStack(spacing: 1) {
            let raw = Int(value * Double(segments))
            let filledCount = value > 0 ? max(raw, 1) : 0
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(i < filledCount ? color : theme.surfaceContainerLowest.opacity(0.2))
                    .overlay(alignment: .trailing) {
                        if i < filledCount {
                            Rectangle().fill(Color.black.opacity(0.3)).frame(width: 1)
                        }
                    }
            }
        }
        .frame(height: 8)
        .padding(2)
        .background(theme.surfaceContainerLowest)
        .overlay(Rectangle().stroke(theme.outlineVariant.opacity(0.2), lineWidth: 1))
    }
}
