import SwiftUI

struct LargeAgentStatusStrip: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let snapshot: LargeAgentSnapshot
    var now: Date = Date()

    var body: some View {
        let color = snapshot.severity.color(theme: theme)
        let isPulsing = snapshot.status == .running
        let detailDisplayText = Self.detailDisplayText(for: snapshot)

        HStack(spacing: 10 * scale) {
            AgentLogoView(kind: snapshot.kind, color: color)
                .frame(width: 32 * scale, height: 32 * scale)
                .neonGlow(color: color, radius: 6 * scale)
                .accessibilityIdentifier("agentLogo-\(snapshot.kind.rawValue)")
                .accessibilityLabel("\(snapshot.displayName) logo")

            Rectangle()
                .fill(color)
                .frame(width: 4 * scale)
                .neonGlow(color: color, radius: 8 * scale)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(snapshot.displayName.uppercased())
                    .font(AppTheme.headlineFont(size: 15 * scale))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(snapshot.status.label)
                    .font(AppTheme.labelFont(size: 9 * scale))
                    .foregroundColor(color)
                    .padding(.horizontal, 6 * scale)
                    .padding(.vertical, 2 * scale)
                    .overlay {
                        Rectangle().stroke(color.opacity(0.6), lineWidth: 1)
                    }
            }
            .layoutPriority(1)

            Spacer(minLength: 8 * scale)

            HStack(spacing: 8 * scale) {
                PulseDot(color: color, isPulsing: isPulsing)
                    .frame(width: 8 * scale, height: 8 * scale)
                    .accessibilityHidden(true)

                Text(detailDisplayText)
                    .font(AppTheme.labelFont(size: 14 * scale))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("agentDetail-\(snapshot.kind.rawValue)")
                    .accessibilityLabel(snapshot.statusLine)
            }
            .layoutPriority(1)

            Spacer(minLength: 8 * scale)

            VStack(alignment: .trailing, spacing: 4 * scale) {
                Text("SIGNAL \(snapshot.ageText(now: now))")
                    .font(AppTheme.monoFont(size: 8 * scale))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6 * scale) {
                    Text(snapshot.tokenSummary?.formattedTokens ?? "--")
                    Text(snapshot.tokenSummary?.formattedCost ?? "--")
                }
                .font(AppTheme.labelFont(size: 12 * scale))
                .foregroundColor(theme.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 110 * scale, alignment: .trailing)
        }
        .padding(.vertical, 10 * scale)
        .padding(.trailing, 12 * scale)
        .background(theme.surfaceContainer.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(color.opacity(0.25)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(snapshot.displayName), \(snapshot.status.accessibilityPhrase), \(snapshot.statusLine), signal age \(snapshot.ageText(now: now))")
        .accessibilityIdentifier("largeAgentStatus-\(snapshot.kind.rawValue)")
    }

    /// Center text uppercases short detail strings (1-3 words) so they read as
    /// pixel-style status chips; leaves longer fallback sentences in their original
    /// case so VoiceOver and visual readers don't get shouted at.
    static func detailDisplayText(for snapshot: LargeAgentSnapshot) -> String {
        let raw = snapshot.statusLine
        if let detail = snapshot.detail, !detail.isEmpty, detail.split(separator: " ").count <= 3 {
            return detail.uppercased()
        }
        return raw
    }
}

private struct AgentLogoView: View {
    let kind: LargeAgentKind
    let color: Color

    var body: some View {
        switch kind {
        case .openClaw:
            LobsterShape(
                bodyColor: color,
                antennaColor: color.opacity(0.7),
                eyeHighlightColor: Color(hex: 0x00E5CC)
            )
        case .hermes:
            HermesWingShape(
                bodyColor: color,
                accentColor: Color(hex: 0x00E5CC)
            )
        }
    }
}

private struct PulseDot: View {
    let color: Color
    let isPulsing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .phaseAnimator([false, true], trigger: shouldAnimate) { view, phase in
                view.opacity(shouldAnimate && phase ? 0.4 : 1.0)
            } animation: { _ in
                shouldAnimate ? .easeInOut(duration: 1.2) : .linear(duration: 0)
            }
    }

    private var shouldAnimate: Bool {
        isPulsing && !reduceMotion
    }
}
