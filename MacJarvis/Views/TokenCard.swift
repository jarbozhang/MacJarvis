import SwiftUI

struct TokenCard: View {
    let usage: ToolUsage
    let accentColor: Color
    let subtitle: String
    let iconName: String
    let budget: Int

    private var percentage: Double? {
        // API-reported percentage (e.g. Claude)
        if let pct = usage.usagePercent {
            return min(Double(pct) / 100.0, 1.0)
        }
        // Budget-based percentage (e.g. Codex)
        guard budget > 0, let total = usage.totalTokens else { return nil }
        return min(Double(total) / Double(budget), 1.0)
    }

    private var usageText: String {
        // API percentage mode (Claude)
        if let pct = usage.usagePercent {
            let plan = usage.planName ?? "Plan"
            return "\(plan) 5h: \(pct)%"
        }
        if usage.totalTokens != nil {
            let formatted = usage.formattedTokens
            let budgetFormatted = formatNumber(budget)
            return "\(formatted)/\(budgetFormatted)"
        } else if let msgs = usage.messageCount {
            return "\(msgs) msg"
        }
        return "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.name.uppercased())
                        .font(CyberTheme.headlineFont(size: 9))
                        .foregroundColor(accentColor)
                    Text(subtitle)
                        .font(CyberTheme.labelFont(size: 7))
                        .foregroundColor(CyberTheme.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: iconName)
                    .foregroundColor(accentColor)
                    .font(.system(size: 14))
            }

            Spacer()

            HStack(alignment: .bottom) {
                if let pct = percentage {
                    Text("\(Int(pct * 100))%")
                        .font(CyberTheme.headlineFont(size: 18))
                        .foregroundColor(CyberTheme.onSurface)
                } else if usage.totalTokens == nil, let msgs = usage.messageCount {
                    Text("\(msgs)")
                        .font(CyberTheme.headlineFont(size: 18))
                        .foregroundColor(CyberTheme.onSurface)
                    Text("msg")
                        .font(CyberTheme.labelFont(size: 8))
                        .foregroundColor(CyberTheme.onSurfaceVariant)
                } else {
                    Text("--")
                        .font(CyberTheme.headlineFont(size: 18))
                        .foregroundColor(CyberTheme.onSurface)
                }
                Spacer()
                Text(usageText)
                    .font(CyberTheme.labelFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)
            }

            if let pct = percentage {
                PixelProgressBar(value: pct, color: accentColor)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(CyberTheme.surfaceContainerLow.opacity(0.6))
        .overlay(alignment: .leading) {
            Rectangle().fill(accentColor).frame(width: 2)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.0fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
