import Foundation

enum LargeAgentKind: String, CaseIterable, Identifiable {
    case openClaw = "openclaw"
    case hermes = "hermes"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openClaw: return "OpenClaw"
        case .hermes: return "Hermes"
        }
    }
}

enum LargeAgentRuntimeStatus: String, Equatable {
    case unknown
    case offline
    case idle
    case running
    case stuck
    case error

    var label: String {
        switch self {
        case .unknown: return "CHECKING"
        case .offline: return "OFFLINE"
        case .idle: return "IDLE"
        case .running: return "RUNNING"
        case .stuck: return "STUCK"
        case .error: return "ERROR"
        }
    }

    var accessibilityPhrase: String {
        switch self {
        case .unknown: return "Agent status is being checked"
        case .offline: return "Installed agent is offline"
        case .idle: return "Agent is online and idle"
        case .running: return "Agent is online and running"
        case .stuck: return "Agent appears stuck; activity is stale"
        case .error: return "Agent reported an error"
        }
    }
}

enum LargeAgentSeverity: Int, Comparable {
    case neutral = 0
    case normal = 1
    case active = 2
    case warning = 3
    case error = 4

    static func < (lhs: LargeAgentSeverity, rhs: LargeAgentSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct AgentTokenSummary: Equatable {
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var cost: Double?
    var bucket: TimeBucket
    var lastUpdated: Date?

    init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        totalTokens: Int = 0,
        cost: Double? = nil,
        bucket: TimeBucket = .all,
        lastUpdated: Date? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cost = cost
        self.bucket = bucket
        self.lastUpdated = lastUpdated
    }

    var hasData: Bool {
        totalTokens > 0 || inputTokens > 0 || outputTokens > 0 || cost != nil
    }

    var formattedTokens: String {
        Self.formatTokens(totalTokens)
    }

    var formattedCost: String {
        guard let cost, cost > 0 else { return "--" }
        if cost < 0.01 { return String(format: "$%.4f", cost) }
        return String(format: "$%.2f", cost)
    }

    static func from(records: [TokenRecord], bucket: TimeBucket = .all, now: Date = Date()) -> AgentTokenSummary {
        let aggregate = aggregateTokens(records, bucket: bucket, now: now)
        return AgentTokenSummary(
            inputTokens: aggregate.inputTokens,
            outputTokens: aggregate.outputTokens,
            totalTokens: aggregate.totalTokens,
            cost: ModelPricing.cost(totalTokens: aggregate.totalTokens, price: ModelPricing.codexDefault),
            bucket: bucket,
            lastUpdated: now
        )
    }

    static func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}

struct LargeAgentSnapshot: Identifiable, Equatable {
    var kind: LargeAgentKind
    var displayName: String
    var isInstalled: Bool
    var status: LargeAgentRuntimeStatus
    var lastActivityAt: Date?
    var lastHeartbeatAt: Date?
    var detail: String?
    var tokenSummary: AgentTokenSummary?

    var id: String { kind.rawValue }

    init(
        kind: LargeAgentKind,
        displayName: String? = nil,
        isInstalled: Bool,
        status: LargeAgentRuntimeStatus,
        lastActivityAt: Date? = nil,
        lastHeartbeatAt: Date? = nil,
        detail: String? = nil,
        tokenSummary: AgentTokenSummary? = nil
    ) {
        self.kind = kind
        self.displayName = displayName ?? kind.displayName
        self.isInstalled = isInstalled
        self.status = status
        self.lastActivityAt = lastActivityAt
        self.lastHeartbeatAt = lastHeartbeatAt
        self.detail = detail
        self.tokenSummary = tokenSummary
    }

    var severity: LargeAgentSeverity {
        guard isInstalled else { return .neutral }
        switch status {
        case .unknown: return .neutral
        case .idle: return .normal
        case .running: return .active
        case .stuck: return .warning
        case .offline, .error: return .error
        }
    }

    var interruptsRotation: Bool {
        isInstalled && (status == .stuck || status == .offline || status == .error)
    }

    var newestSignalAt: Date? {
        switch (lastActivityAt, lastHeartbeatAt) {
        case let (activity?, heartbeat?):
            return max(activity, heartbeat)
        case let (activity?, nil):
            return activity
        case let (nil, heartbeat?):
            return heartbeat
        case (nil, nil):
            return nil
        }
    }

    func evaluatingStaleness(now: Date, stuckAfter threshold: TimeInterval = 120) -> LargeAgentSnapshot {
        guard isInstalled, status == .running, let newestSignalAt else { return self }
        guard now.timeIntervalSince(newestSignalAt) > threshold else { return self }

        var copy = self
        copy.status = .stuck
        if copy.detail == nil {
            copy.detail = "Activity stale for \(Self.formatAge(now.timeIntervalSince(newestSignalAt)))"
        }
        return copy
    }

    static func formatAge(_ seconds: TimeInterval) -> String {
        let clamped = max(0, Int(seconds))
        if clamped < 60 { return "\(clamped)s" }
        let minutes = clamped / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }
}

enum LargeAgentGlobalHealth: Equatable {
    case noInstalled
    case checking
    case nominal
    case active
    case stuck
    case offline
    case error

    var headline: String {
        switch self {
        case .noInstalled: return "NO LARGE AGENTS"
        case .checking: return "CHECKING AGENTS"
        case .nominal: return "SYSTEM NOMINAL"
        case .active: return "AGENT ACTIVE"
        case .stuck: return "AGENT STUCK"
        case .offline: return "AGENT OFFLINE"
        case .error: return "AGENT ERROR"
        }
    }

    var severity: LargeAgentSeverity {
        switch self {
        case .noInstalled, .checking: return .neutral
        case .nominal: return .normal
        case .active: return .active
        case .stuck: return .warning
        case .offline, .error: return .error
        }
    }

    var interruptsRotation: Bool {
        switch self {
        case .stuck, .offline, .error: return true
        case .noInstalled, .checking, .nominal, .active: return false
        }
    }

    var accessibilityPhrase: String {
        switch self {
        case .noInstalled: return "No large agents configured"
        case .checking: return "Agent status is being checked"
        case .nominal: return "Large agents are online and idle"
        case .active: return "A large agent is active"
        case .stuck: return "A large agent appears stuck"
        case .offline: return "An installed large agent is offline"
        case .error: return "A large agent reported an error"
        }
    }

    static func from(_ snapshots: [LargeAgentSnapshot]) -> LargeAgentGlobalHealth {
        let installed = snapshots.installedLargeAgents
        guard !installed.isEmpty else { return .noInstalled }
        if installed.contains(where: { $0.status == .error }) { return .error }
        if installed.contains(where: { $0.status == .offline }) { return .offline }
        if installed.contains(where: { $0.status == .stuck }) { return .stuck }
        if installed.contains(where: { $0.status == .running }) { return .active }
        if installed.allSatisfy({ $0.status == .unknown }) { return .checking }
        return .nominal
    }

    static func shouldClearInterrupt(successfulReadCount: Int, stableFor: TimeInterval) -> Bool {
        successfulReadCount >= 2 || stableFor >= 15
    }
}

extension Array where Element == LargeAgentSnapshot {
    var installedLargeAgents: [LargeAgentSnapshot] {
        filter(\.isInstalled)
    }
}
