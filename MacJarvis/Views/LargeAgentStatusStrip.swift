import SwiftUI

struct LargeAgentStatusStrip: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let snapshot: LargeAgentSnapshot
    var now: Date = Date()

    var body: some View {
        let color = snapshot.severity.color(theme: theme)
        let isPulsing = snapshot.status == .running

        HStack(spacing: 10 * scale) {
            AgentLogoView(kind: snapshot.kind, color: color)
                .frame(width: 32 * scale, height: 32 * scale)
                .neonGlow(color: color, radius: 6 * scale)
                .accessibilityHidden(true)
                .accessibilityIdentifier("agentLogo-\(snapshot.kind.rawValue)")

            Rectangle()
                .fill(color)
                .frame(width: 4 * scale)
                .neonGlow(color: color, radius: 8 * scale)

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

            Spacer(minLength: 8 * scale)

            HStack(spacing: 8 * scale) {
                PulseDot(color: color, isPulsing: isPulsing, reduceMotion: reduceMotion)
                    .frame(width: 8 * scale, height: 8 * scale)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("agentPulse-\(snapshot.kind.rawValue)")

                Text(snapshot.statusLine.uppercased())
                    .font(AppTheme.labelFont(size: 14 * scale))
                    .tracking(1 * scale)
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("agentDetail-\(snapshot.kind.rawValue)")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.displayName), \(snapshot.status.accessibilityPhrase), \(snapshot.statusLine), signal age \(snapshot.ageText(now: now))")
        .accessibilityIdentifier("largeAgentStatus-\(snapshot.kind.rawValue)")
    }
}

private struct AgentLogoView: View {
    let kind: LargeAgentKind
    let color: Color

    var body: some View {
        switch kind {
        case .openClaw:
            LobsterShape(bodyColor: color, antennaColor: color, eyeHighlightColor: color)
        case .hermes:
            HermesWingShape(bodyColor: color, accentColor: color)
        }
    }
}

private struct PulseDot: View {
    let color: Color
    let isPulsing: Bool
    let reduceMotion: Bool

    var body: some View {
        if isPulsing && !reduceMotion {
            Circle()
                .fill(color)
                .phaseAnimator([false, true]) { view, phase in
                    view.opacity(phase ? 1.0 : 0.4)
                } animation: { _ in
                    .easeInOut(duration: 1.2)
                }
        } else {
            Circle()
                .fill(color)
        }
    }
}
