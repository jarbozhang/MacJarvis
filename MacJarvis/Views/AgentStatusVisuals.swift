import SwiftUI

extension LargeAgentSeverity {
    func color(theme: AppTheme) -> Color {
        switch self {
        case .neutral: return theme.onSurfaceVariant
        case .normal: return theme.primary
        case .active: return theme.primary
        case .warning: return Color(hex: 0xFFB020)
        case .error: return theme.error
        }
    }
}

extension LargeAgentSnapshot {
    func ageText(now: Date = Date()) -> String {
        guard let newestSignalAt else { return "--" }
        return LargeAgentSnapshot.formatAge(now.timeIntervalSince(newestSignalAt))
    }

    var statusLine: String {
        if let detail, !detail.isEmpty {
            return detail
        }
        return status.accessibilityPhrase
    }
}

extension ToolUsage {
    var compactUsageText: String {
        if let usagePercent {
            return "\(usagePercent)%"
        }
        if totalTokens != nil {
            return formattedTokens
        }
        return "--"
    }

    var hasConsumptionData: Bool {
        usagePercent != nil || totalTokens != nil || cost != nil
    }
}
