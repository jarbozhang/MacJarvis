import SwiftUI

struct LobsterShape: View {
    var bodyColor: Color = Color(hex: 0xFF8E80)
    var antennaColor: Color = Color(hex: 0xFF6B6B)
    var eyeHighlightColor: Color = Color(hex: 0x00E5CC)
    var isBlinking: Bool = false

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 120
            let scaleY = size.height / 120

            // Body
            var bodyPath = Path()
            bodyPath.move(to: CGPoint(x: 60 * scaleX, y: 10 * scaleY))
            bodyPath.addCurve(to: CGPoint(x: 15 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 30 * scaleX, y: 10 * scaleY),
                control2: CGPoint(x: 15 * scaleX, y: 35 * scaleY))
            bodyPath.addCurve(to: CGPoint(x: 45 * scaleX, y: 100 * scaleY),
                control1: CGPoint(x: 15 * scaleX, y: 75 * scaleY),
                control2: CGPoint(x: 30 * scaleX, y: 95 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 45 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 55 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 55 * scaleX, y: 100 * scaleY))
            bodyPath.addCurve(to: CGPoint(x: 65 * scaleX, y: 100 * scaleY),
                control1: CGPoint(x: 60 * scaleX, y: 102 * scaleY),
                control2: CGPoint(x: 65 * scaleX, y: 100 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 65 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 75 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 75 * scaleX, y: 100 * scaleY))
            bodyPath.addCurve(to: CGPoint(x: 105 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 90 * scaleX, y: 95 * scaleY),
                control2: CGPoint(x: 105 * scaleX, y: 75 * scaleY))
            bodyPath.addCurve(to: CGPoint(x: 60 * scaleX, y: 10 * scaleY),
                control1: CGPoint(x: 105 * scaleX, y: 35 * scaleY),
                control2: CGPoint(x: 90 * scaleX, y: 10 * scaleY))
            bodyPath.closeSubpath()
            context.fill(bodyPath, with: .color(bodyColor))

            // Left claw
            var leftClaw = Path()
            leftClaw.move(to: CGPoint(x: 20 * scaleX, y: 45 * scaleY))
            leftClaw.addCurve(to: CGPoint(x: 5 * scaleX, y: 60 * scaleY),
                control1: CGPoint(x: 5 * scaleX, y: 40 * scaleY),
                control2: CGPoint(x: 0 * scaleX, y: 50 * scaleY))
            leftClaw.addCurve(to: CGPoint(x: 25 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 10 * scaleX, y: 70 * scaleY),
                control2: CGPoint(x: 20 * scaleX, y: 65 * scaleY))
            leftClaw.addCurve(to: CGPoint(x: 20 * scaleX, y: 45 * scaleY),
                control1: CGPoint(x: 28 * scaleX, y: 48 * scaleY),
                control2: CGPoint(x: 25 * scaleX, y: 45 * scaleY))
            leftClaw.closeSubpath()
            context.fill(leftClaw, with: .color(bodyColor))

            // Right claw
            var rightClaw = Path()
            rightClaw.move(to: CGPoint(x: 100 * scaleX, y: 45 * scaleY))
            rightClaw.addCurve(to: CGPoint(x: 115 * scaleX, y: 60 * scaleY),
                control1: CGPoint(x: 115 * scaleX, y: 40 * scaleY),
                control2: CGPoint(x: 120 * scaleX, y: 50 * scaleY))
            rightClaw.addCurve(to: CGPoint(x: 95 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 110 * scaleX, y: 70 * scaleY),
                control2: CGPoint(x: 100 * scaleX, y: 65 * scaleY))
            rightClaw.addCurve(to: CGPoint(x: 100 * scaleX, y: 45 * scaleY),
                control1: CGPoint(x: 92 * scaleX, y: 48 * scaleY),
                control2: CGPoint(x: 95 * scaleX, y: 45 * scaleY))
            rightClaw.closeSubpath()
            context.fill(rightClaw, with: .color(bodyColor))

            // Left antenna
            var leftAntenna = Path()
            leftAntenna.move(to: CGPoint(x: 45 * scaleX, y: 15 * scaleY))
            leftAntenna.addQuadCurve(to: CGPoint(x: 30 * scaleX, y: 8 * scaleY),
                control: CGPoint(x: 35 * scaleX, y: 5 * scaleY))
            context.stroke(leftAntenna, with: .color(antennaColor),
                style: StrokeStyle(lineWidth: 2 * min(scaleX, scaleY), lineCap: .round))

            // Right antenna
            var rightAntenna = Path()
            rightAntenna.move(to: CGPoint(x: 75 * scaleX, y: 15 * scaleY))
            rightAntenna.addQuadCurve(to: CGPoint(x: 90 * scaleX, y: 8 * scaleY),
                control: CGPoint(x: 85 * scaleX, y: 5 * scaleY))
            context.stroke(rightAntenna, with: .color(antennaColor),
                style: StrokeStyle(lineWidth: 2 * min(scaleX, scaleY), lineCap: .round))

            // Eyes
            let eyeColor = Color(hex: 0x050810)
            if isBlinking {
                // Blink: draw closed eyes as horizontal lines
                var leftEyeLine = Path()
                leftEyeLine.move(to: CGPoint(x: (45 - 6) * scaleX, y: 35 * scaleY))
                leftEyeLine.addLine(to: CGPoint(x: (45 + 6) * scaleX, y: 35 * scaleY))
                context.stroke(leftEyeLine, with: .color(eyeColor),
                    style: StrokeStyle(lineWidth: 2 * min(scaleX, scaleY), lineCap: .round))

                var rightEyeLine = Path()
                rightEyeLine.move(to: CGPoint(x: (75 - 6) * scaleX, y: 35 * scaleY))
                rightEyeLine.addLine(to: CGPoint(x: (75 + 6) * scaleX, y: 35 * scaleY))
                context.stroke(rightEyeLine, with: .color(eyeColor),
                    style: StrokeStyle(lineWidth: 2 * min(scaleX, scaleY), lineCap: .round))
            } else {
                // Open eyes
                let leftEye = CGRect(x: (45 - 6) * scaleX, y: (35 - 6) * scaleY, width: 12 * scaleX, height: 12 * scaleY)
                let rightEye = CGRect(x: (75 - 6) * scaleX, y: (35 - 6) * scaleY, width: 12 * scaleX, height: 12 * scaleY)
                context.fill(Path(ellipseIn: leftEye), with: .color(eyeColor))
                context.fill(Path(ellipseIn: rightEye), with: .color(eyeColor))

                let leftHL = CGRect(x: (46 - 2) * scaleX, y: (34 - 2) * scaleY, width: 4 * scaleX, height: 4 * scaleY)
                let rightHL = CGRect(x: (76 - 2) * scaleX, y: (34 - 2) * scaleY, width: 4 * scaleX, height: 4 * scaleY)
                context.fill(Path(ellipseIn: leftHL), with: .color(eyeHighlightColor))
                context.fill(Path(ellipseIn: rightHL), with: .color(eyeHighlightColor))
            }
        }
    }
}
