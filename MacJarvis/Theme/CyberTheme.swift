import SwiftUI

// MARK: - View Modifiers
struct NeonGlow: ViewModifier {
    var color: Color
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.4), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.2), radius: radius * 1.5, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color, radius: CGFloat = 20) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}

// MARK: - Floating Animation (OpenClaw float)
// translateY(0) → translateY(-8px) → translateY(0), 4s ease-in-out infinite
struct FloatingModifier: ViewModifier {
    var amplitude: CGFloat = 4
    var duration: Double = 4

    func body(content: Content) -> some View {
        content
            .phaseAnimator([false, true]) { view, phase in
                view.offset(y: phase ? -amplitude : amplitude)
            } animation: { _ in
                .easeInOut(duration: duration)
            }
    }
}

extension View {
    func floating(amplitude: CGFloat = 4, duration: Double = 4) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, duration: duration))
    }
}

// MARK: - Gradient Shift Text (OpenClaw gradientShift)
// 3-color gradient that shifts position over 6s, using AnimatableModifier for smooth interpolation
struct GradientShiftText: View {
    @Environment(\.theme) var theme
    let text: String
    let font: Font
    let tracking: CGFloat

    var body: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(.clear)
            .overlay {
                // 2x wide gradient, animate horizontal offset
                GeometryReader { geo in
                    GradientShiftLayer(
                        colors: [
                            Color(hex: 0xF0F4FF),
                            theme.primary,
                            Color(hex: 0x00E5CC),
                            Color(hex: 0xF0F4FF)
                        ],
                        width: geo.size.width,
                        height: geo.size.height
                    )
                }
                .mask {
                    Text(text)
                        .font(font)
                        .tracking(tracking)
                }
            }
    }
}

// Separate view to use phaseAnimator on the gradient offset
private struct GradientShiftLayer: View {
    let colors: [Color]
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width * 2)
        .phaseAnimator([false, true]) { view, phase in
            view.offset(x: phase ? 0 : -width)
        } animation: { _ in
            .easeInOut(duration: 6)
        }
        .frame(width: width, height: height, alignment: .leading)
        .clipped()
    }
}

// MARK: - FadeInUp Entrance Animation (OpenClaw fadeInUp)
struct FadeInUpModifier: ViewModifier {
    var delay: Double = 0
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func fadeInUp(delay: Double = 0) -> some View {
        modifier(FadeInUpModifier(delay: delay))
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
