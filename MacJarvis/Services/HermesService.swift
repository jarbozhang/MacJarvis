import Foundation
import SQLite3

@Observable
@MainActor
final class HermesService {
    var fixtureSnapshot: LargeAgentSnapshot?
    private let homeDirectory: String
    private let fileManager: FileManager

    init(homeDirectory: String = NSHomeDirectory(), fileManager: FileManager = .default) {
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
    }

    func snapshot(now: Date) async -> LargeAgentSnapshot {
        if let fixtureSnapshot {
            return fixtureSnapshot.evaluatingStaleness(now: now)
        }

        let homeDirectory = homeDirectory
        let fileManager = fileManager
        return await Task.detached(priority: .utility) {
            Self.snapshot(homeDirectory: homeDirectory, fileManager: fileManager, now: now)
        }.value
    }

    nonisolated static func snapshot(
        homeDirectory: String = NSHomeDirectory(),
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> LargeAgentSnapshot {
        let hermesDirectory = homeDirectory + "/.hermes"
        guard fileManager.fileExists(atPath: hermesDirectory) else {
            return LargeAgentSnapshot(
                kind: .hermes,
                isInstalled: false,
                status: .unknown,
                detail: "Hermes directory not found"
            )
        }

        let gatewayState = readGatewayState(path: hermesDirectory + "/gateway_state.json", fileManager: fileManager)
        let pidInfo = readGatewayPID(path: hermesDirectory + "/gateway.pid", fileManager: fileManager)
        let tokenSummary = readTokenSummary(dbPath: hermesDirectory + "/state.db", now: now, fileManager: fileManager)
        let status = runtimeStatus(gatewayState: gatewayState, pidInfo: pidInfo, fileManager: fileManager)
        let detail = statusDetail(gatewayState: gatewayState, pidInfo: pidInfo)

        return LargeAgentSnapshot(
            kind: .hermes,
            isInstalled: true,
            status: status,
            lastActivityAt: tokenSummary?.lastUpdated,
            lastHeartbeatAt: gatewayState?.updatedAt,
            detail: detail,
            tokenSummary: tokenSummary
        ).evaluatingStaleness(now: now)
    }

    nonisolated static func readGatewayState(
        path: String,
        fileManager: FileManager = .default
    ) -> HermesGatewayState? {
        guard fileManager.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let platforms = (json["platforms"] as? [String: Any])?.compactMapValues { value -> HermesPlatformState? in
            guard let platform = value as? [String: Any] else { return nil }
            return HermesPlatformState(
                state: stringValue(platform["state"]),
                errorCode: stringValue(platform["error_code"]),
                errorMessage: stringValue(platform["error_message"]),
                updatedAt: parseHermesDate(stringValue(platform["updated_at"]))
            )
        } ?? [:]

        return HermesGatewayState(
            pid: intValue(json["pid"]),
            gatewayState: stringValue(json["gateway_state"]),
            activeAgents: intValue(json["active_agents"]) ?? 0,
            platforms: platforms,
            updatedAt: parseHermesDate(stringValue(json["updated_at"]))
        )
    }

    nonisolated static func readGatewayPID(
        path: String,
        fileManager: FileManager = .default
    ) -> HermesPIDInfo? {
        guard fileManager.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return HermesPIDInfo(
            pid: intValue(json["pid"]),
            kind: stringValue(json["kind"])
        )
    }

    nonisolated static func readTokenSummary(
        dbPath: String,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> AgentTokenSummary? {
        guard fileManager.fileExists(atPath: dbPath) else { return nil }

        var db: OpaquePointer?
        let uri = "file:" + dbPath + "?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = """
            SELECT
                COALESCE(SUM(input_tokens), 0),
                COALESCE(SUM(output_tokens), 0),
                COALESCE(SUM(input_tokens + output_tokens + cache_read_tokens + cache_write_tokens + reasoning_tokens), 0),
                COALESCE(SUM(COALESCE(actual_cost_usd, estimated_cost_usd, 0)), 0),
                MAX(COALESCE(ended_at, started_at))
            FROM sessions
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let inputTokens = Int(sqlite3_column_int64(stmt, 0))
        let outputTokens = Int(sqlite3_column_int64(stmt, 1))
        let totalTokens = Int(sqlite3_column_int64(stmt, 2))
        let cost = sqlite3_column_double(stmt, 3)
        let lastUpdated = sqlite3_column_type(stmt, 4) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))

        guard inputTokens > 0 || outputTokens > 0 || totalTokens > 0 || cost > 0 else {
            return nil
        }

        return AgentTokenSummary(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            cost: cost > 0 ? cost : nil,
            lastUpdated: lastUpdated ?? now
        )
    }

    nonisolated static func isPrivateOrLocalHost(_ host: String) -> Bool {
        let lowercased = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowercased.isEmpty else { return false }
        if lowercased == "localhost" || lowercased == "127.0.0.1" || lowercased == "::1" {
            return true
        }
        if lowercased.hasPrefix("10.") || lowercased.hasPrefix("192.168.") {
            return true
        }

        let parts = lowercased.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4, parts[0] == 172, (16...31).contains(parts[1]) {
            return true
        }

        return false
    }

    private nonisolated static func runtimeStatus(
        gatewayState: HermesGatewayState?,
        pidInfo: HermesPIDInfo?,
        fileManager: FileManager
    ) -> LargeAgentRuntimeStatus {
        guard let gatewayState else {
            return pidInfo?.pid == nil ? .unknown : .idle
        }

        if let errorPlatform = gatewayState.platforms.values.first(where: { platform in
            if let state = platform.state?.lowercased(), state == "error" || state == "failed" {
                return true
            }
            return !(platform.errorCode?.isEmpty ?? true) || !(platform.errorMessage?.isEmpty ?? true)
        }) {
            return (errorPlatform.errorCode == nil && errorPlatform.errorMessage == nil) ? .error : .error
        }

        let state = gatewayState.gatewayState?.lowercased()
        if state == "error" || state == "failed" || state == "crashed" {
            return .error
        }

        if let pid = gatewayState.pid ?? pidInfo?.pid, !isProcessRunning(pid: pid, fileManager: fileManager) {
            return .offline
        }

        if gatewayState.activeAgents > 0 {
            return .running
        }

        if state == "running" || state == "started" || state == "ready" {
            return .idle
        }

        return .unknown
    }

    private nonisolated static func statusDetail(
        gatewayState: HermesGatewayState?,
        pidInfo: HermesPIDInfo?
    ) -> String {
        guard let gatewayState else {
            return pidInfo?.pid == nil ? "Hermes installed" : "Hermes gateway pid recorded"
        }

        if let failing = gatewayState.platforms.first(where: { _, platform in
            !(platform.errorMessage?.isEmpty ?? true) || !(platform.errorCode?.isEmpty ?? true)
        }) {
            return "\(failing.key) \(failing.value.errorMessage ?? failing.value.errorCode ?? "error")"
        }

        let connected = gatewayState.platforms
            .filter { _, platform in platform.state?.lowercased() == "connected" }
            .map(\.key)
            .sorted()

        if gatewayState.activeAgents > 0 {
            return "\(gatewayState.activeAgents) active Hermes agent\(gatewayState.activeAgents == 1 ? "" : "s")"
        }
        if !connected.isEmpty {
            return "\(connected.joined(separator: ", ")) connected"
        }
        if let state = gatewayState.gatewayState, !state.isEmpty {
            return "Gateway \(state)"
        }
        return "Hermes installed"
    }

    private nonisolated static func isProcessRunning(pid: Int, fileManager: FileManager) -> Bool {
        guard pid > 0 else { return false }
        return fileManager.fileExists(atPath: "/proc/\(pid)") || kill(pid_t(pid), 0) == 0 || errno == EPERM
    }

    private nonisolated static func parseHermesDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private nonisolated static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if value is NSNull { return nil }
        return "\(value)"
    }

    private nonisolated static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let int64 as Int64:
            return Int(int64)
        case let double as Double:
            return Int(double)
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }
}

struct HermesGatewayState: Equatable {
    var pid: Int?
    var gatewayState: String?
    var activeAgents: Int
    var platforms: [String: HermesPlatformState]
    var updatedAt: Date?
}

struct HermesPlatformState: Equatable {
    var state: String?
    var errorCode: String?
    var errorMessage: String?
    var updatedAt: Date?
}

struct HermesPIDInfo: Equatable {
    var pid: Int?
    var kind: String?
}
