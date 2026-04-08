import SwiftUI

struct TokenCard: View {
    @Environment(\.theme) var theme
    @Environment(TokenService.self) private var tokenService
    let usage: ToolUsage
    let accentColor: Color
    let subtitle: String
    let iconName: String
    let budget: Int

    private var percentage: Double? {
        guard !usage.isAPIMode else { return nil }
        if let pct = usage.usagePercent {
            return min(Double(pct) / 100.0, 1.0)
        }
        guard budget > 0, let total = usage.totalTokens else { return nil }
        return min(Double(total) / Double(budget), 1.0)
    }

    private var usageText: String {
        if usage.isAPIMode {
            return usage.formattedCost
        }
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
                        .font(AppTheme.headlineFont(size: 9))
                        .foregroundColor(accentColor)
                    Text(subtitle)
                        .font(AppTheme.labelFont(size: 7))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                Spacer()
                if usage.isAPIMode {
                    // Time bucket badge
                    Text(usage.timeBucket.rawValue)
                        .font(AppTheme.headlineFont(size: 7))
                        .tracking(1)
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.15))
                } else {
                    Image(systemName: iconName)
                        .foregroundColor(accentColor)
                        .font(.system(size: 14))
                }
            }

            Spacer()

            if usage.isAPIMode {
                // API mode: token count + cost
                HStack(alignment: .bottom) {
                    Text(usage.formattedTokens)
                        .font(AppTheme.headlineFont(size: 18))
                        .foregroundColor(theme.onSurface)
                    Spacer()
                    Text(usageText)
                        .font(AppTheme.headlineFont(size: 12))
                        .foregroundColor(accentColor)
                }
            } else {
                // Subscription mode: percentage or message count
                HStack(alignment: .bottom) {
                    if let pct = percentage {
                        Text("\(Int(pct * 100))%")
                            .font(AppTheme.headlineFont(size: 18))
                            .foregroundColor(theme.onSurface)
                    } else if usage.totalTokens == nil, let msgs = usage.messageCount {
                        Text("\(msgs)")
                            .font(AppTheme.headlineFont(size: 18))
                            .foregroundColor(theme.onSurface)
                        Text("msg")
                            .font(AppTheme.labelFont(size: 8))
                            .foregroundColor(theme.onSurfaceVariant)
                    } else {
                        Text("--")
                            .font(AppTheme.headlineFont(size: 18))
                            .foregroundColor(theme.onSurface)
                    }
                    Spacer()
                    Text(usageText)
                        .font(AppTheme.labelFont(size: 7))
                        .textCase(.uppercase)
                        .foregroundColor(theme.onSurfaceVariant)
                }

                if let pct = percentage {
                    PixelProgressBar(value: pct, color: accentColor)
                        .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(theme.surfaceContainerLow.opacity(0.6))
        .overlay(alignment: .leading) {
            Rectangle().fill(accentColor).frame(width: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard usage.isAPIMode else { return }
            let nextBucket = usage.timeBucket.next
            tokenService.updateBucket(for: usage.id, bucket: nextBucket)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.0fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
