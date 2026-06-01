import SwiftUI

struct ConsumptionDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale
    @Environment(TokenService.self) private var tokenService
    @Environment(LargeAgentStatusService.self) private var largeAgentStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            PageTitle(title: "CONSUMPTION", subtitle: "LARGE AGENT USAGE FIRST")

            VStack(spacing: 8 * scale) {
                if largeAgentStatus.installedAgents.isEmpty {
                    MutedRow(title: "LARGE AGENTS", value: "--", detail: "No OpenClaw or Hermes provider installed")
                } else {
                    ForEach(largeAgentStatus.installedAgents) { snapshot in
                        ConsumptionRow(
                            title: snapshot.displayName,
                            label: snapshot.status.label,
                            tokens: snapshot.tokenSummary?.formattedTokens ?? "--",
                            cost: snapshot.tokenSummary?.formattedCost ?? "--",
                            detail: "large agent status + usage",
                            color: snapshot.severity.color(theme: theme)
                        )
                    }
                }
            }

            Rectangle()
                .fill(theme.outlineVariant.opacity(0.35))
                .frame(height: 1)

            VStack(spacing: 8 * scale) {
                ForEach(tokenService.tools) { tool in
                    ConsumptionRow(
                        title: tool.name,
                        label: "USAGE ONLY",
                        tokens: tool.compactUsageText,
                        cost: tool.formattedCost,
                        detail: smallAgentDetail(tool),
                        color: color(for: tool.id)
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18 * scale)
        .accessibilityIdentifier("consumptionDetail")
    }

    private func color(for id: String) -> Color {
        switch id {
        case "codex": return theme.primary
        case "gemini": return theme.secondary
        case "claude": return theme.tertiary
        default: return theme.onSurfaceVariant
        }
    }

    private func smallAgentDetail(_ tool: ToolUsage) -> String {
        if let lastUpdated = tool.lastUpdated {
            return "updated \(LargeAgentSnapshot.formatAge(Date().timeIntervalSince(lastUpdated))) ago"
        }
        return tool.hasConsumptionData ? "consumption source active" : "missing or stale consumption data"
    }
}

struct ConsumptionRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let title: String
    let label: String
    let tokens: String
    let cost: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 12 * scale) {
            VStack(alignment: .leading, spacing: 4 * scale) {
                HStack(spacing: 8 * scale) {
                    Text(title.uppercased())
                        .font(AppTheme.headlineFont(size: 16 * scale))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(label)
                        .font(AppTheme.monoFont(size: 8 * scale))
                        .foregroundColor(color)
                        .lineLimit(1)
                }
                Text(detail)
                    .font(AppTheme.bodyFont(size: 9 * scale))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer(minLength: 8 * scale)

            HStack(spacing: 18 * scale) {
                MetricBlock(title: "TOKENS", value: tokens, color: color)
                MetricBlock(title: "COST", value: cost, color: theme.onSurface)
            }
        }
        .padding(10 * scale)
        .background(theme.surfaceContainer.opacity(0.58))
        .overlay(alignment: .leading) {
            Rectangle().fill(color.opacity(0.7)).frame(width: 3 * scale)
        }
    }
}
