import Foundation

// MARK: - Time Bucket

enum TimeBucket: String, CaseIterable {
    case hour = "1H"
    case day = "1D"
    case week = "1W"

    var next: TimeBucket {
        switch self {
        case .hour: return .day
        case .day: return .week
        case .week: return .hour
        }
    }

    /// Start date for the current bucket window
    func windowStart(from now: Date = Date()) -> Date {
        let cal = Calendar.current
        switch self {
        case .hour:
            return cal.date(byAdding: .hour, value: -1, to: now)!
        case .day:
            return cal.startOfDay(for: now)
        case .week:
            return cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now))!
        }
    }
}

// MARK: - Token Record

struct TokenRecord {
    let date: Date
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
}

// MARK: - Model Pricing

struct ModelPricing {
    /// Price per million tokens: (input, output)
    struct Price {
        let inputPerMillion: Double
        let outputPerMillion: Double
    }

    // Claude models (2026 pricing)
    static let prices: [String: Price] = [
        "claude-opus":   Price(inputPerMillion: 15.0, outputPerMillion: 75.0),
        "claude-sonnet": Price(inputPerMillion: 3.0,  outputPerMillion: 15.0),
        "claude-haiku":  Price(inputPerMillion: 0.80, outputPerMillion: 4.0),
        // OpenAI models
        "openai":        Price(inputPerMillion: 2.50, outputPerMillion: 10.0),  // gpt-4o default
    ]

    /// Default pricing when model is unknown
    static let claudeDefault = prices["claude-opus"]!
    static let codexDefault = prices["openai"]!

    /// Calculate cost from token counts
    static func cost(inputTokens: Int, outputTokens: Int, price: Price) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000.0 * price.inputPerMillion
        let outputCost = Double(outputTokens) / 1_000_000.0 * price.outputPerMillion
        return inputCost + outputCost
    }

    /// Calculate cost for total tokens only (no input/output split, uses average)
    static func cost(totalTokens: Int, price: Price) -> Double {
        let avgPerMillion = (price.inputPerMillion + price.outputPerMillion) / 2.0
        return Double(totalTokens) / 1_000_000.0 * avgPerMillion
    }
}

// MARK: - Aggregation

func aggregateTokens(_ records: [TokenRecord], bucket: TimeBucket, now: Date = Date()) -> TokenRecord {
    let windowStart = bucket.windowStart(from: now)
    let filtered = records.filter { $0.date >= windowStart }
    let totalInput = filtered.reduce(0) { $0 + $1.inputTokens }
    let totalOutput = filtered.reduce(0) { $0 + $1.outputTokens }
    let total = filtered.reduce(0) { $0 + $1.totalTokens }
    return TokenRecord(date: now, inputTokens: totalInput, outputTokens: totalOutput, totalTokens: total)
}
