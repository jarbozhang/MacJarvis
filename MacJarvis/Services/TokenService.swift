import Foundation
import SQLite3

@Observable
@MainActor
class TokenService {
    var tools: [ToolUsage] = [
        ToolUsage(id: "codex", name: "Codex"),
        ToolUsage(id: "claude", name: "Claude"),
        ToolUsage(id: "gemini", name: "Gemini"),
    ]

    private var refreshTimer: Timer?
    private let codexDbPath: String
    private let claudeUsageCachePath: String
    private let geminiBasePath: String

    init(codexDbPath: String? = nil, claudeUsageCachePath: String? = nil, geminiBasePath: String? = nil) {
        self.codexDbPath = codexDbPath ?? (NSHomeDirectory() + "/.codex/state_5.sqlite")
        self.claudeUsageCachePath = claudeUsageCachePath ?? (NSHomeDirectory() + "/.claude/plugins/claude-hud/.usage-cache.json")
        self.geminiBasePath = geminiBasePath ?? (NSHomeDirectory() + "/.gemini/tmp")
    }

    func startAutoRefresh() {
        fetchAll()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchAll()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchAll() {
        let codexPath = codexDbPath
        let claudePath = claudeUsageCachePath
        let geminiPath = geminiBasePath
        Task.detached {
            let codexUsage = Self.queryCodexDatabase(at: codexPath)
            let claudeUsage = Self.queryClaudeUsageCache(path: claudePath)
            let geminiUsage = Self.queryGeminiSessions(basePath: geminiPath)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let usage = codexUsage, let idx = self.tools.firstIndex(where: { $0.id == "codex" }) {
                    self.tools[idx].totalTokens = usage.totalTokens
                    self.tools[idx].sessionCount = usage.sessionCount
                    self.tools[idx].lastUpdated = Date()
                }
                if let usage = claudeUsage, let idx = self.tools.firstIndex(where: { $0.id == "claude" }) {
                    self.tools[idx].usagePercent = usage.fiveHourPercent
                    self.tools[idx].planName = usage.planName
                    self.tools[idx].lastUpdated = Date()
                }
                if let usage = geminiUsage, let idx = self.tools.firstIndex(where: { $0.id == "gemini" }) {
                    self.tools[idx].sessionCount = usage.sessionCount
                    self.tools[idx].lastUpdated = Date()
                }
            }
        }
    }

    nonisolated static func queryCodexDatabase(at path: String) -> (totalTokens: Int, sessionCount: Int)? {
        var db: OpaquePointer?
        // Use immutable URI to avoid WAL file access issues when Codex is running
        let uri = "file:\(path)?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        // Calculate start-of-day in local timezone as Unix timestamp
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let startOfDayUnix = Int(startOfDay.timeIntervalSince1970)

        let sql = """
        SELECT COALESCE(SUM(tokens_used), 0), COUNT(*)
        FROM threads
        WHERE created_at >= \(startOfDayUnix);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        let totalTokens = Int(sqlite3_column_int64(stmt, 0))
        let sessionCount = Int(sqlite3_column_int64(stmt, 1))
        return (totalTokens, sessionCount)
    }

    nonisolated static func queryClaudeUsageCache(path: String? = nil) -> (fiveHourPercent: Int, planName: String?)? {
        let filePath = path ?? (NSHomeDirectory() + "/.claude/plugins/claude-hud/.usage-cache.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Check freshness (cache is valid for 10 minutes)
        if let timestamp = json["timestamp"] as? Double {
            let age = Date().timeIntervalSince1970 - (timestamp / 1000.0)
            if age > 600 { return nil }
        }

        let cacheData = json["data"] as? [String: Any] ?? json["lastGoodData"] as? [String: Any]
        guard let cacheData else { return nil }

        let fiveHour = cacheData["fiveHour"] as? Int ?? 0
        let planName = cacheData["planName"] as? String
        return (fiveHour, planName)
    }

    nonisolated static func queryGeminiSessions(basePath: String? = nil) -> (sessionCount: Int, messageCount: Int)? {
        let base = basePath ?? (NSHomeDirectory() + "/.gemini/tmp")
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayPrefix = "session-" + formatter.string(from: Date())

        var totalSessions = 0

        for projectDir in projectDirs {
            let chatsPath = (base as NSString).appendingPathComponent("\(projectDir)/chats")
            guard let files = try? fm.contentsOfDirectory(atPath: chatsPath) else { continue }

            for file in files where file.hasPrefix(todayPrefix) && file.hasSuffix(".json") {
                totalSessions += 1
            }
        }

        guard totalSessions > 0 else { return nil }
        return (totalSessions, 0)
    }
}
