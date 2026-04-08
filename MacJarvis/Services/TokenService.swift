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
    // Cached API mode records for time bucket switching without re-reading files
    var claudeRecords: [TokenRecord] = []
    var codexRecords: [TokenRecord] = []

    func startAutoRefresh(settings: SettingsService? = nil) {
        fetchAll(settings: settings)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchAll(settings: settings)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Re-aggregate cached records for a new time bucket (no file I/O)
    func updateBucket(for toolId: String, bucket: TimeBucket) {
        guard let idx = tools.firstIndex(where: { $0.id == toolId }) else { return }
        tools[idx].timeBucket = bucket
        let records = toolId == "claude" ? claudeRecords : codexRecords
        guard !records.isEmpty else { return }
        let agg = aggregateTokens(records, bucket: bucket)
        tools[idx].inputTokens = agg.inputTokens
        tools[idx].outputTokens = agg.outputTokens
        tools[idx].totalTokens = agg.totalTokens
        if toolId == "claude" {
            tools[idx].cost = ModelPricing.cost(inputTokens: agg.inputTokens, outputTokens: agg.outputTokens, price: ModelPricing.claudeDefault)
        } else {
            tools[idx].cost = ModelPricing.cost(totalTokens: agg.totalTokens, price: ModelPricing.codexDefault)
        }
    }

    func fetchAll(settings: SettingsService? = nil) {
        let codexAuthPath = NSHomeDirectory() + "/.codex/auth.json"
        let codexConfigPath = NSHomeDirectory() + "/.codex/config.toml"
        let geminiCredsPath = NSHomeDirectory() + "/.gemini/oauth_creds.json"
        let claudeMode = settings?.claudeMode ?? .subscription
        let codexMode = settings?.codexMode ?? .subscription
        Task.detached {
            // Subscription mode fetches
            let codexSubUsage = codexMode == .subscription ? await Self.queryCodexUsageAPI(authPath: codexAuthPath) : nil
            let codexModel = Self.readCodexModel(configPath: codexConfigPath)
            let claudeHudPath = NSHomeDirectory() + "/.claude/plugins/claude-hud/.usage-cache.json"
            let claudeSubUsage = claudeMode == .subscription ? Self.queryClaudeUsageCache(path: claudeHudPath) : nil
            let geminiUsage = await Self.queryGeminiUsageAPI(credsPath: geminiCredsPath)

            // API mode fetches
            let claudeAPIRecords = claudeMode == .api ? Self.fetchClaudeAPIUsage() : []
            let codexAPIRecords = codexMode == .api ? Self.fetchCodexAPIUsage() : []

            await MainActor.run { [weak self] in
                guard let self else { return }

                // Codex
                if let idx = self.tools.firstIndex(where: { $0.id == "codex" }) {
                    self.tools[idx].modelName = codexModel
                    self.tools[idx].lastUpdated = Date()
                    if codexMode == .api {
                        self.tools[idx].isAPIMode = true
                        self.codexRecords = codexAPIRecords
                        let bucket = self.tools[idx].timeBucket
                        let agg = aggregateTokens(codexAPIRecords, bucket: bucket)
                        self.tools[idx].totalTokens = agg.totalTokens
                        self.tools[idx].inputTokens = agg.inputTokens
                        self.tools[idx].outputTokens = agg.outputTokens
                        self.tools[idx].cost = ModelPricing.cost(totalTokens: agg.totalTokens, price: ModelPricing.codexDefault)
                        self.tools[idx].usagePercent = nil
                    } else {
                        self.tools[idx].isAPIMode = false
                        if let usage = codexSubUsage {
                            self.tools[idx].usagePercent = usage.usedPercent
                            self.tools[idx].planName = usage.planType
                        }
                        self.tools[idx].totalTokens = nil
                        self.tools[idx].cost = nil
                    }
                }

                // Claude
                if let idx = self.tools.firstIndex(where: { $0.id == "claude" }) {
                    self.tools[idx].lastUpdated = Date()
                    if claudeMode == .api {
                        self.tools[idx].isAPIMode = true
                        self.claudeRecords = claudeAPIRecords
                        let bucket = self.tools[idx].timeBucket
                        let agg = aggregateTokens(claudeAPIRecords, bucket: bucket)
                        self.tools[idx].inputTokens = agg.inputTokens
                        self.tools[idx].outputTokens = agg.outputTokens
                        self.tools[idx].totalTokens = agg.totalTokens
                        self.tools[idx].cost = ModelPricing.cost(inputTokens: agg.inputTokens, outputTokens: agg.outputTokens, price: ModelPricing.claudeDefault)
                        self.tools[idx].usagePercent = nil
                    } else {
                        self.tools[idx].isAPIMode = false
                        if let usage = claudeSubUsage {
                            self.tools[idx].usagePercent = usage.fiveHourPercent
                            self.tools[idx].planName = usage.subscriptionType
                        }
                        self.tools[idx].totalTokens = nil
                        self.tools[idx].cost = nil
                    }
                }

                // Gemini (always subscription)
                if let usage = geminiUsage, let idx = self.tools.firstIndex(where: { $0.id == "gemini" }) {
                    self.tools[idx].usagePercent = usage.usedPercent
                    self.tools[idx].planName = usage.tierName
                    self.tools[idx].modelName = usage.modelName
                    self.tools[idx].lastUpdated = Date()
                }
            }
        }
    }

    nonisolated static func readCodexModel(configPath: String) -> String? {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
        // Parse `model = "gpt-5.4"` from TOML
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("model") && trimmed.contains("=") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                guard key == "model" else { continue }
                let value = parts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return value
            }
        }
        return nil
    }

    nonisolated static func queryCodexUsageAPI(authPath: String) async -> (usedPercent: Int, planType: String?)? {
        // Read OAuth credentials from ~/.codex/auth.json
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: authPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String else {
            return nil
        }
        let accountId = tokens["account_id"] as? String

        // Call ChatGPT backend API for Codex usage
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.timeoutInterval = 10

        guard let (responseData, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let result = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return nil
        }

        // Parse rate_limit.primary_window.used_percent (5-hour window)
        var usedPercent = 0
        if let rateLimit = result["rate_limit"] as? [String: Any],
           let primaryWindow = rateLimit["primary_window"] as? [String: Any],
           let pct = primaryWindow["used_percent"] as? Double {
            usedPercent = Int(pct)
        }

        let planType = result["plan_type"] as? String
        return (usedPercent, planType)
    }

    nonisolated static func queryClaudeUsageCache(path: String) -> (fiveHourPercent: Int, subscriptionType: String?)? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
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

    nonisolated static func queryGeminiUsageAPI(credsPath: String) async -> (usedPercent: Int, tierName: String?, modelName: String?)? {
        // Read OAuth credentials from ~/.gemini/oauth_creds.json
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: credsPath)),
              let creds = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = creds["access_token"] as? String else {
            return nil
        }

        // Step 1: Get project ID via loadCodeAssist
        guard let loadUrl = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist") else { return nil }
        var loadReq = URLRequest(url: loadUrl)
        loadReq.httpMethod = "POST"
        loadReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        loadReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        loadReq.httpBody = try? JSONSerialization.data(withJSONObject: [
            "metadata": ["ideType": "GEMINI_CLI", "pluginType": "GEMINI"]
        ])
        loadReq.timeoutInterval = 10

        guard let (loadData, loadResp) = try? await URLSession.shared.data(for: loadReq),
              let loadHttp = loadResp as? HTTPURLResponse, loadHttp.statusCode == 200,
              let loadJson = try? JSONSerialization.jsonObject(with: loadData) as? [String: Any],
              let projectId = loadJson["cloudaicompanionProject"] as? String else {
            return nil
        }

        let tierName = (loadJson["currentTier"] as? [String: Any])?["id"] as? String

        // Step 2: Get quota via retrieveUserQuota
        guard let quotaUrl = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota") else { return nil }
        var quotaReq = URLRequest(url: quotaUrl)
        quotaReq.httpMethod = "POST"
        quotaReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        quotaReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        quotaReq.httpBody = try? JSONSerialization.data(withJSONObject: ["project": projectId])
        quotaReq.timeoutInterval = 10

        guard let (quotaData, quotaResp) = try? await URLSession.shared.data(for: quotaReq),
              let quotaHttp = quotaResp as? HTTPURLResponse, quotaHttp.statusCode == 200,
              let quotaJson = try? JSONSerialization.jsonObject(with: quotaData) as? [String: Any],
              let buckets = quotaJson["buckets"] as? [[String: Any]] else {
            return nil
        }

        // Find the highest usage among gemini-3 models
        var maxUsed: Double = 0
        var maxModelId: String?
        for bucket in buckets {
            guard let modelId = bucket["modelId"] as? String,
                  modelId.hasPrefix("gemini-3"),
                  let remaining = bucket["remainingFraction"] as? Double else { continue }
            let used = 1.0 - remaining
            if used > maxUsed {
                maxUsed = used
                maxModelId = modelId
            }
        }

        return (Int(maxUsed * 100), tierName, maxModelId)
    }

    // MARK: - API Mode Readers

    nonisolated static func fetchClaudeAPIUsage() -> [TokenRecord] {
        let metaDir = NSHomeDirectory() + "/.claude/usage-data/session-meta"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: metaDir) else { return [] }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var records: [TokenRecord] = []
        for file in files where file.hasSuffix(".json") {
            let path = metaDir + "/" + file
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let startTime = json["start_time"] as? String,
                  let date = isoFormatter.date(from: startTime) else { continue }
            let input = json["input_tokens"] as? Int ?? 0
            let output = json["output_tokens"] as? Int ?? 0
            records.append(TokenRecord(date: date, inputTokens: input, outputTokens: output, totalTokens: input + output))
        }
        return records
    }

    nonisolated static func fetchCodexAPIUsage() -> [TokenRecord] {
        let dbPath = NSHomeDirectory() + "/.codex/state_5.sqlite"
        guard FileManager.default.fileExists(atPath: dbPath) else { return [] }

        var db: OpaquePointer?
        let uri = "file:" + dbPath + "?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT tokens_used, created_at FROM threads WHERE tokens_used > 0"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var records: [TokenRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let tokensUsed = Int(sqlite3_column_int64(stmt, 0))
            let createdAt = Double(sqlite3_column_int64(stmt, 1))
            let date = Date(timeIntervalSince1970: createdAt)
            records.append(TokenRecord(date: date, inputTokens: 0, outputTokens: 0, totalTokens: tokensUsed))
        }
        return records
    }
}
