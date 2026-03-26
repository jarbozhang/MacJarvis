import SwiftUI

struct CRTEffect: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(
            CRTScanlines()
                .allowsHitTesting(false)
        )
    }
}

struct CRTScanlines: View {
    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.15)))
                y += lineSpacing
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func crtEffect() -> some View {
        modifier(CRTEffect())
    }
}

// MARK: - Pixel Grid Background
struct PixelGridBackground: View {
    @Environment(\.theme) var theme
    var dotColor: Color?
    var spacing: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let dotRadius: CGFloat = 0.5
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor ?? theme.outlineVariant))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func pixelGrid() -> some View {
        self.background(PixelGridBackground())
    }
}
