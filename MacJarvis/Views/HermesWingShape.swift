import SwiftUI

struct HermesWingShape: View {
    var bodyColor: Color = Color(hex: 0x9EC9FF)
    var accentColor: Color = Color(hex: 0x00E5CC)

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 120
            let scaleY = size.height / 120

            // Center gem (diamond)
            var gem = Path()
            gem.move(to: CGPoint(x: 60 * scaleX, y: 40 * scaleY))
            gem.addLine(to: CGPoint(x: 72 * scaleX, y: 60 * scaleY))
            gem.addLine(to: CGPoint(x: 60 * scaleX, y: 86 * scaleY))
            gem.addLine(to: CGPoint(x: 48 * scaleX, y: 60 * scaleY))
            gem.closeSubpath()
            context.fill(gem, with: .color(bodyColor))

            // Gem highlight
            var gemHighlight = Path()
            gemHighlight.move(to: CGPoint(x: 60 * scaleX, y: 46 * scaleY))
            gemHighlight.addLine(to: CGPoint(x: 66 * scaleX, y: 60 * scaleY))
            gemHighlight.addLine(to: CGPoint(x: 60 * scaleX, y: 70 * scaleY))
            gemHighlight.addLine(to: CGPoint(x: 54 * scaleX, y: 60 * scaleY))
            gemHighlight.closeSubpath()
            context.fill(gemHighlight, with: .color(accentColor.opacity(0.8)))

            // Left wing — three stacked feathers
            drawFeather(
                in: &context,
                tip: CGPoint(x: 8 * scaleX, y: 36 * scaleY),
                root: CGPoint(x: 48 * scaleX, y: 50 * scaleY),
                width: 10 * min(scaleX, scaleY),
                color: bodyColor
            )
            drawFeather(
                in: &context,
                tip: CGPoint(x: 4 * scaleX, y: 56 * scaleY),
                root: CGPoint(x: 46 * scaleX, y: 60 * scaleY),
                width: 11 * min(scaleX, scaleY),
                color: bodyColor
            )
            drawFeather(
                in: &context,
                tip: CGPoint(x: 10 * scaleX, y: 78 * scaleY),
                root: CGPoint(x: 48 * scaleX, y: 70 * scaleY),
                width: 9 * min(scaleX, scaleY),
                color: bodyColor.opacity(0.85)
            )

            // Right wing — mirrored
            drawFeather(
                in: &context,
                tip: CGPoint(x: 112 * scaleX, y: 36 * scaleY),
                root: CGPoint(x: 72 * scaleX, y: 50 * scaleY),
                width: 10 * min(scaleX, scaleY),
                color: bodyColor
            )
            drawFeather(
                in: &context,
                tip: CGPoint(x: 116 * scaleX, y: 56 * scaleY),
                root: CGPoint(x: 74 * scaleX, y: 60 * scaleY),
                width: 11 * min(scaleX, scaleY),
                color: bodyColor
            )
            drawFeather(
                in: &context,
                tip: CGPoint(x: 110 * scaleX, y: 78 * scaleY),
                root: CGPoint(x: 72 * scaleX, y: 70 * scaleY),
                width: 9 * min(scaleX, scaleY),
                color: bodyColor.opacity(0.85)
            )

            // Quill spines on accent color
            var spineLeft = Path()
            spineLeft.move(to: CGPoint(x: 48 * scaleX, y: 60 * scaleY))
            spineLeft.addLine(to: CGPoint(x: 12 * scaleX, y: 58 * scaleY))
            context.stroke(
                spineLeft,
                with: .color(accentColor),
                style: StrokeStyle(lineWidth: 1.5 * min(scaleX, scaleY), lineCap: .round)
            )

            var spineRight = Path()
            spineRight.move(to: CGPoint(x: 72 * scaleX, y: 60 * scaleY))
            spineRight.addLine(to: CGPoint(x: 108 * scaleX, y: 58 * scaleY))
            context.stroke(
                spineRight,
                with: .color(accentColor),
                style: StrokeStyle(lineWidth: 1.5 * min(scaleX, scaleY), lineCap: .round)
            )
        }
    }

    private func drawFeather(
        in context: inout GraphicsContext,
        tip: CGPoint,
        root: CGPoint,
        width: CGFloat,
        color: Color
    ) {
        var feather = Path()
        let dx = root.x - tip.x
        let dy = root.y - tip.y
        let length = max(sqrt(dx * dx + dy * dy), 0.0001)
        let normalX = -dy / length
        let normalY = dx / length
        let offsetX = normalX * width / 2
        let offsetY = normalY * width / 2

        feather.move(to: tip)
        feather.addLine(to: CGPoint(x: root.x + offsetX, y: root.y + offsetY))
        feather.addLine(to: CGPoint(x: root.x - offsetX, y: root.y - offsetY))
        feather.closeSubpath()
        context.fill(feather, with: .color(color))
    }
}
