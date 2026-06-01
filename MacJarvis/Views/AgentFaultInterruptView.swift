import SwiftUI

struct AgentFaultInterruptView: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(LargeAgentStatusService.self) private var largeAgentStatus

    var now: Date = Date()

    var body: some View {
        let health = largeAgentStatus.globalHealth
        let color = health.severity.color(theme: theme)
        let affected = largeAgentStatus.installedAgents.filter(\.interruptsRotation)

        VStack(spacing: 16 * scale) {
            Spacer(minLength: 0)

            Text(health.headline)
                .font(AppTheme.headlineFont(size: 58 * scale))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .neonGlow(color: color, radius: reduceMotion ? 0 : 22 * scale)
                .accessibilityIdentifier("faultHeadline")

            VStack(spacing: 8 * scale) {
                ForEach(affected.isEmpty ? largeAgentStatus.installedAgents : affected) { snapshot in
                    LargeAgentStatusStrip(snapshot: snapshot, now: now)
                }
            }

            Text("ROTATION PAUSED UNTIL LARGE AGENT RECOVERS")
                .font(AppTheme.monoFont(size: 10 * scale))
                .tracking(1.5 * scale)
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 10 * scale)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(health.accessibilityPhrase)
        .accessibilityIdentifier("faultInterrupt")
    }
}

struct PageTitle: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(title)
                .font(AppTheme.headlineFont(size: 34 * scale))
                .foregroundColor(theme.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(subtitle)
                .font(AppTheme.labelFont(size: 10 * scale))
                .tracking(2 * scale)
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.primary.opacity(0.25)).frame(height: 1).offset(y: 8 * scale)
        }
        .padding(.bottom, 8 * scale)
    }
}

struct MetricBlock: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 3 * scale) {
            Text(title)
                .font(AppTheme.monoFont(size: 7 * scale))
                .foregroundColor(theme.onSurfaceVariant)
            Text(value)
                .font(AppTheme.headlineFont(size: 18 * scale))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(minWidth: 72 * scale, alignment: .trailing)
    }
}

struct MutedRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(title)
                    .font(AppTheme.headlineFont(size: 14 * scale))
                    .foregroundColor(theme.onSurfaceVariant)
                Text(detail)
                    .font(AppTheme.bodyFont(size: 9 * scale))
                    .foregroundColor(theme.onSurfaceVariant.opacity(0.8))
            }
            Spacer()
            Text(value)
                .font(AppTheme.headlineFont(size: 18 * scale))
                .foregroundColor(theme.onSurfaceVariant)
        }
        .padding(10 * scale)
        .background(theme.surfaceContainer.opacity(0.4))
    }
}
