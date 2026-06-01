import SwiftUI

struct AgentStatusWallView: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(LargeAgentStatusService.self) private var largeAgentStatus

    var now: Date = Date()
    var viewportWidth: CGFloat = 1024

    var body: some View {
        let health = largeAgentStatus.globalHealth
        let color = health.severity.color(theme: theme)

        VStack(spacing: 14 * scale) {
            Spacer(minLength: 6 * scale)

            VStack(spacing: 8 * scale) {
                Text(health.headline)
                    .font(AppTheme.headlineFont(size: headlineSize))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .neonGlow(color: color, radius: reduceMotion ? 0 : 18 * scale)
                    .accessibilityIdentifier("globalStatus")

                Text(globalSubhead)
                    .font(AppTheme.labelFont(size: 12 * scale))
                    .tracking(2 * scale)
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8 * scale)
            .overlay(alignment: .bottom) {
                Rectangle().fill(color.opacity(0.35)).frame(height: 1)
            }

            if largeAgentStatus.installedAgents.isEmpty {
                zeroAgentState
            } else {
                VStack(spacing: 8 * scale) {
                    ForEach(largeAgentStatus.installedAgents) { snapshot in
                        LargeAgentStatusStrip(snapshot: snapshot, now: now)
                    }
                }
            }

            Spacer(minLength: 4 * scale)

            HStack(spacing: 10 * scale) {
                CompactConsumptionStrip()
                CompactSystemStrip(showDisk: viewportWidth >= 1180)
            }
            .frame(minHeight: 104 * scale)
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 10 * scale)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(health.accessibilityPhrase)
        .accessibilityIdentifier("statusWall")
    }

    private var headlineSize: CGFloat {
        let base = viewportWidth < 1100 ? 48.0 : 60.0
        return base * scale
    }

    private var globalSubhead: String {
        let installed = largeAgentStatus.installedAgents.count
        if installed == 0 { return "TOKEN AND LOCAL LOAD REMAIN VISIBLE" }
        if installed == 1 { return "1 LARGE AGENT TRACKED" }
        return "\(installed) LARGE AGENTS TRACKED"
    }

    private var zeroAgentState: some View {
        VStack(spacing: 8 * scale) {
            Text("OPENCLAW / HERMES NOT DETECTED")
                .font(AppTheme.labelFont(size: 15 * scale))
                .foregroundColor(theme.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text("NO FAULT RAISED")
                .font(AppTheme.monoFont(size: 10 * scale))
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 92 * scale)
        .background(theme.surfaceContainer.opacity(0.45))
        .overlay {
            Rectangle().stroke(theme.outlineVariant.opacity(0.5), lineWidth: 1)
        }
        .accessibilityIdentifier("noLargeAgentsState")
    }
}
