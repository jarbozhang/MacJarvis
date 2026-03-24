import Foundation

struct ToolUsage: Identifiable {
    let id: String
    var name: String
    var inputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?
    var cost: Double?
    var sessionCount: Int?
    var messageCount: Int?
    var lastUpdated: Date?
    var usagePercent: Int?   // API-reported usage percentage (e.g. Claude 5-hour)
    var planName: String?    // Subscription plan (e.g. "Max", "Pro")
    var modelName: String?   // Active model (e.g. "gpt-5.4", "gemini-3-flash")

    var formattedActivity: String {
        if totalTokens != nil {
            return formattedTokens
        }
        guard let msgs = messageCount else { return "--" }
        return "\(msgs)msg"
    }

    var formattedTokens: String {
        guard let tokens = totalTokens else { return "--" }
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}
