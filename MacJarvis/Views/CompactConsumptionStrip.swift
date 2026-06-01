import SwiftUI

struct CompactConsumptionStrip: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale
    @Environment(TokenService.self) private var tokenService
    @Environment(LargeAgentStatusService.self) private var largeAgentStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            StripHeader(title: "CONSUMPTION", color: theme.secondary)

            HStack(spacing: 8 * scale) {
                ReadoutCell(
                    title: "LARGE",
                    value: largeAgentTokenText,
                    detail: largeAgentCostText,
                    color: theme.secondary
                )

                ForEach(tokenService.tools) { tool in
                    ReadoutCell(
                        title: tool.name.uppercased(),
                        value: tool.compactUsageText,
                        detail: tool.formattedCost,
                        color: smallAgentColor(tool.id)
                    )
                }
            }
        }
        .padding(10 * scale)
        .background(theme.surfaceContainerLow.opacity(0.76))
        .overlay(alignment: .top) {
            Rectangle().fill(theme.secondary.opacity(0.35)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Consumption summary. Large agents \(largeAgentTokenText). Small agents token consumption only.")
        .accessibilityIdentifier("compactConsumption")
    }

    private var largeAgentTokenText: String {
        let total = largeAgentStatus.installedAgents
            .compactMap(\.tokenSummary?.totalTokens)
            .reduce(0, +)
        guard total > 0 else { return "--" }
        return AgentTokenSummary.formatTokens(total)
    }

    private var largeAgentCostText: String {
        let cost = largeAgentStatus.installedAgents
            .compactMap(\.tokenSummary?.cost)
            .reduce(0, +)
        guard cost > 0 else { return "--" }
        if cost < 0.01 { return String(format: "$%.4f", cost) }
        return String(format: "$%.2f", cost)
    }

    private func smallAgentColor(_ id: String) -> Color {
        switch id {
        case "codex": return theme.primary
        case "gemini": return theme.secondary
        case "claude": return theme.tertiary
        default: return theme.onSurfaceVariant
        }
    }
}

struct StripHeader: View {
    @Environment(\.scaleFactor) private var scale
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6 * scale) {
            Rectangle()
                .fill(color)
                .frame(width: 12 * scale, height: 2 * scale)
            Text(title)
                .font(AppTheme.labelFont(size: 8 * scale))
                .tracking(2 * scale)
                .foregroundColor(color)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

struct ReadoutCell: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(title)
                .font(AppTheme.monoFont(size: 7 * scale))
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(value)
                .font(AppTheme.headlineFont(size: 14 * scale))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(detail)
                .font(AppTheme.monoFont(size: 7 * scale))
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 54 * scale)
        .padding(.horizontal, 6 * scale)
        .overlay(alignment: .leading) {
            Rectangle().fill(color.opacity(0.35)).frame(width: 1)
        }
    }
}
