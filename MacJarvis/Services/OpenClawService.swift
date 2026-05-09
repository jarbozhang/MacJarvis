import Foundation

private func clawLog(_ msg: String) {
    let path = "/tmp/macjarvis-claw.log"
    let line = "[\(Date())] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}

@Observable
@MainActor
class OpenClawService {
    var status: ClawStatus = .unknown
    var connectedAt: Date?
    var messages: [ChatMessage] = []
    var mirroredMessages: [ChatMessage] = []
    var mirroredSessionKey: String?
    var mirroredSessionName: String?
    var mirrorStatusText: String = "session mirror idle"
    var isStreaming: Bool = false

    private var baseURL: String = ""
    private var wsURL: String = ""
    private var authToken: String = ""
    private var agentId: String = "main"
    private var streamTask: Task<Void, Never>?
    private var mirrorTask: Task<Void, Never>?
    private var sessionPreviewTask: Task<Void, Never>?
    private var recentSessionMessageId: UUID?
    private var mirroredSessionFile: String?

    // Stable user ID for session persistence across requests
    private let userId = "macjarvis-\(ProcessInfo.processInfo.hostName)"

    /// Test connectivity via /health endpoint (no token cost)
    func connect(host: String, port: Int, token: String = "", agent: String = "main") async {
        baseURL = "http://\(host):\(port)"
        wsURL = "ws://\(host):\(port)"
        authToken = token
        agentId = agent

        clawLog("Connecting to \(self.baseURL) token=\(token.isEmpty ? "none" : "set") agent=\(agent)")

        // Use /health endpoint — no auth needed, no token consumption
        let url = URL(string: "\(baseURL)/health")!
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                status = .running
                connectedAt = Date.now
                clawLog("Connected OK via /health")
                startSessionMirror()
                loadRecentSessionPreview(agent: agent)
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                clawLog("Connect failed: HTTP \(code)")
                status = .error
                connectedAt = nil
            }
        } catch {
            clawLog("Connect error: \(error.localizedDescription)")
            status = .stopped
            connectedAt = nil
        }
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        mirrorTask?.cancel()
        mirrorTask = nil
        sessionPreviewTask?.cancel()
        sessionPreviewTask = nil
        status = .stopped
        connectedAt = nil
    }

    func sendMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
        guard status == .running else { return }

        // Build conversation history (last 20 messages for context)
        let recentMessages = messages
            .filter { $0.id != recentSessionMessageId }
            .suffix(20)
            .map { msg -> [String: String] in
            ["role": msg.role == .user ? "user" : "assistant", "content": msg.content]
        }

        streamTask?.cancel()
        streamTask = Task { [baseURL, authToken, agentId, userId] in
            await self.streamResponse(
                baseURL: baseURL,
                token: authToken,
                agent: agentId,
                user: userId,
                messages: recentMessages
            )
        }
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
    }

    private func loadRecentSessionPreview(agent: String) {
        sessionPreviewTask?.cancel()
        sessionPreviewTask = Task { [agent] in
            let preview = await Task.detached(priority: .utility) {
                OpenClawSessionFormatter.recentSessionPreview(agent: agent)
            }.value

            guard !Task.isCancelled else { return }

            guard let preview else {
                clawLog("Session mirror fallback skipped: no readable recent session for agent=\(agent)")
                return
            }

            guard mirroredSessionFile != preview.sessionFile else { return }
            guard messages.isEmpty, mirroredMessages.isEmpty else {
                clawLog("Session mirror fallback skipped: messages already present")
                return
            }

            let message = ChatMessage(role: .assistant, content: preview.displayContent)
            messages.append(message)
            recentSessionMessageId = message.id
            mirroredSessionFile = preview.sessionFile
            mirrorStatusText = "mirroring recent local session"
            clawLog("Session mirror fallback loaded path=\(preview.sessionFile) chars=\(preview.displayContent.count)")
        }
    }

    // MARK: - Streaming SSE

    private func streamResponse(
        baseURL: String,
        token: String,
        agent: String,
        user: String,
        messages: [[String: String]]
    ) async {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(agent, forHTTPHeaderField: "x-openclaw-agent-id")

        let body: [String: Any] = [
            "model": "openclaw",
            "messages": messages,
            "stream": true,
            "user": user
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        isStreaming = true
        // Pre-create the assistant message placeholder
        let placeholderMsg = ChatMessage(role: .assistant, content: "")
        self.messages.append(placeholderMsg)
        let placeholderId = placeholderMsg.id
        var rawAssistantContent = ""

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // Non-2xx: try to read error
                if let idx = self.messages.firstIndex(where: { $0.id == placeholderId }) {
                    self.messages[idx].content = "[CONNECTION ERROR]"
                }
                isStreaming = false
                return
            }

            for try await line in bytes.lines {
                if Task.isCancelled { break }

                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))
                if payload == "[DONE]" { break }

                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String else { continue }

                rawAssistantContent += content
                if let idx = self.messages.firstIndex(where: { $0.id == placeholderId }) {
                    self.messages[idx].content = OpenClawSessionFormatter.displayContent(from: rawAssistantContent)
                }
            }
        } catch {
            if !Task.isCancelled {
                if let idx = self.messages.firstIndex(where: { $0.id == placeholderId }) {
                    if self.messages[idx].content.isEmpty {
                        self.messages[idx].content = "[ERROR: \(error.localizedDescription)]"
                    }
                }
                status = .error
                connectedAt = nil
            }
        }

        isStreaming = false
    }

    // MARK: - Active Session Mirror

    private func startSessionMirror() {
        mirrorTask?.cancel()
        mirrorStatusText = "discovering active session"

        mirrorTask = Task { [wsURL, authToken] in
            while !Task.isCancelled {
                do {
                    try await self.refreshActiveSessionMirror(wsURL: wsURL, token: authToken)
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    if Task.isCancelled { break }
                    self.mirrorStatusText = "mirror error: \(error.localizedDescription)"
                    clawLog("Session mirror error: \(error.localizedDescription)")
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }

    private func refreshActiveSessionMirror(wsURL: String, token: String) async throws {
        let listPayload = try await gatewayRPC(
            wsURL: wsURL,
            token: token,
            method: "sessions.list",
            params: [
                "limit": 20,
                "includeLastMessage": true,
                "activeMinutes": 43200
            ]
        )

        guard let sessions = listPayload["sessions"] as? [[String: Any]] else {
            mirrorStatusText = "no sessions returned"
            return
        }

        guard let session = selectActiveFeishuSession(from: sessions),
              let key = session["key"] as? String else {
            mirrorStatusText = "no active feishu session"
            return
        }

        let historyPayload = try await gatewayRPC(
            wsURL: wsURL,
            token: token,
            method: "chat.history",
            params: [
                "sessionKey": key,
                "limit": 80,
                "maxChars": 12000
            ]
        )

        guard let rawMessages = historyPayload["messages"] as? [[String: Any]] else {
            mirrorStatusText = "no messages for session"
            return
        }

        mirroredSessionKey = key
        mirroredSessionName = session["displayName"] as? String
        mirroredMessages = rawMessages.compactMap(parseHistoryMessage)
        let displayName = mirroredSessionName?.isEmpty == false ? mirroredSessionName! : key
        mirrorStatusText = "mirroring \(displayName)"
    }

    private func selectActiveFeishuSession(from sessions: [[String: Any]]) -> [String: Any]? {
        sessions.first { session in
            if let key = session["key"] as? String, key.contains(":feishu:") {
                return true
            }
            if let lastChannel = session["lastChannel"] as? String, lastChannel == "feishu" {
                return true
            }
            if let delivery = session["deliveryContext"] as? [String: Any],
               delivery["channel"] as? String == "feishu" {
                return true
            }
            if let origin = session["origin"] as? [String: Any],
               origin["provider"] as? String == "feishu" || origin["surface"] as? String == "feishu" {
                return true
            }
            return false
        }
    }

    private func parseHistoryMessage(_ raw: [String: Any]) -> ChatMessage? {
        guard let roleValue = raw["role"] as? String else { return nil }
        let role: ChatMessage.Role
        switch roleValue {
        case "user":
            role = .user
        case "assistant":
            role = .assistant
        default:
            return nil
        }

        let content = OpenClawSessionFormatter.displayMessageContent(
            role: role,
            rawContent: extractMessageText(raw["content"])
        )
        guard !content.isEmpty else { return nil }

        let timestamp: Date
        if let ms = raw["timestamp"] as? Double, ms > 0 {
            timestamp = Date(timeIntervalSince1970: ms / 1000)
        } else if let ms = raw["timestamp"] as? Int, ms > 0 {
            timestamp = Date(timeIntervalSince1970: Double(ms) / 1000)
        } else {
            timestamp = Date()
        }

        return ChatMessage(role: role, content: content, timestamp: timestamp)
    }

    private func extractMessageText(_ content: Any?) -> String {
        if let text = content as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let parts = content as? [[String: Any]] {
            return parts.compactMap { part in
                if let text = part["text"] as? String {
                    return text
                }
                if let media = part["media"] as? [String: Any],
                   let path = media["path"] as? String {
                    return "[media] \(path)"
                }
                return nil
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func gatewayRPC(
        wsURL: String,
        token: String,
        method: String,
        params: [String: Any]
    ) async throws -> [String: Any] {
        guard let url = URL(string: wsURL) else {
            throw URLError(.badURL)
        }

        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        var connected = false
        let connectId = UUID().uuidString
        let requestId = UUID().uuidString

        while !Task.isCancelled {
            let frame = try await receiveJSON(from: task)
            guard let type = frame["type"] as? String else { continue }

            if type == "event",
               frame["event"] as? String == "connect.challenge",
               !connected {
                try await sendJSON(
                    [
                        "type": "req",
                        "id": connectId,
                        "method": "connect",
                        "params": connectParams(token: token)
                    ],
                    to: task
                )
                continue
            }

            if type == "res", frame["id"] as? String == connectId {
                if frame["ok"] as? Bool == true {
                    connected = true
                    try await sendJSON(
                        [
                            "type": "req",
                            "id": requestId,
                            "method": method,
                            "params": params
                        ],
                        to: task
                    )
                } else {
                    throw gatewayError(from: frame)
                }
                continue
            }

            if type == "res", frame["id"] as? String == requestId {
                if frame["ok"] as? Bool == true {
                    return frame["payload"] as? [String: Any] ?? [:]
                }
                throw gatewayError(from: frame)
            }
        }

        throw URLError(.cancelled)
    }

    private func connectParams(token: String) -> [String: Any] {
        var params: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "gateway-client",
                "displayName": "MacJarvis",
                "version": "MacJarvis",
                "platform": "darwin",
                "mode": "backend",
                "instanceId": userId
            ],
            "caps": [],
            "role": "operator",
            "scopes": [
                "operator.admin",
                "operator.read",
                "operator.write",
                "operator.approvals",
                "operator.pairing",
                "operator.talk.secrets"
            ]
        ]
        if !token.isEmpty {
            params["auth"] = ["token": token]
        }
        return params
    }

    private func sendJSON(_ object: [String: Any], to task: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        try await task.send(.string(text))
    }

    private func receiveJSON(from task: URLSessionWebSocketTask) async throws -> [String: Any] {
        let message = try await task.receive()
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let raw):
            data = raw
        @unknown default:
            throw URLError(.cannotDecodeContentData)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }

    private func gatewayError(from frame: [String: Any]) -> Error {
        let error = frame["error"] as? [String: Any]
        let message = error?["message"] as? String ?? "gateway request failed"
        return NSError(domain: "OpenClawGateway", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
enum OpenClawSessionFormatter {
    struct SessionPreview {
        let sessionFile: String
        let displayContent: String
    }

    private enum TranscriptRole {
        case user
        case assistant
    }

    private struct TranscriptSegment {
        let role: TranscriptRole
        let text: String
    }

    private struct SessionCandidate {
        let sessionFile: String
        let updatedAt: Double
        let metadata: String
    }

    private static let userCharacterLimit = 500
    private static let assistantCharacterLimit = 900
    private static let fallbackCharacterLimit = 1400
    private static let userLineLimit = 8
    private static let assistantLineLimit = 14
    private static let fallbackLineLimit = 24
    private static let recentSessionSegmentLimit = 8

    static func recentSessionPreview(
        agent: String,
        homeDirectory: String = NSHomeDirectory()
    ) -> SessionPreview? {
        let sessionsDirectory = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("agents")
            .appendingPathComponent(agent)
            .appendingPathComponent("sessions")

        let indexURL = sessionsDirectory.appendingPathComponent("sessions.json")
        var candidates: [SessionCandidate] = []

        if let rawIndex = try? String(contentsOf: indexURL, encoding: .utf8) {
            candidates.append(contentsOf: sessionCandidates(from: rawIndex))
        }

        candidates.append(contentsOf: fallbackSessionCandidates(in: sessionsDirectory))

        var seenFiles = Set<String>()
        for candidate in candidates.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard !isBackgroundSession(candidate) else { continue }

            let sessionURL = resolvedSessionURL(
                from: candidate.sessionFile,
                homeDirectory: homeDirectory,
                sessionsDirectory: sessionsDirectory
            )
            let sessionPath = sessionURL.path
            guard seenFiles.insert(sessionPath).inserted else { continue }
            guard isPrimarySessionFile(sessionURL.lastPathComponent) else { continue }
            guard let rawSession = try? String(contentsOf: sessionURL, encoding: .utf8) else { continue }

            let display = displayContent(from: rawSession, maxSegments: recentSessionSegmentLimit)
            guard !display.isEmpty else { continue }
            return SessionPreview(sessionFile: sessionPath, displayContent: display)
        }

        return nil
    }

    static func displayContent(from rawContent: String, maxSegments: Int? = nil) -> String {
        let rawContent = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawContent.isEmpty else { return "" }

        if let structuredTranscript = formattedStructuredTranscript(from: rawContent, maxSegments: maxSegments) {
            return structuredTranscript
        }

        if looksLikeStructuredSessionContent(rawContent) {
            return ""
        }

        return truncated(
            cleanCommonText(rawContent),
            characterLimit: fallbackCharacterLimit,
            lineLimit: fallbackLineLimit
        )
    }

    static func displayMessageContent(role: ChatMessage.Role, rawContent: String) -> String {
        switch role {
        case .user:
            return truncated(
                cleanUserText(rawContent),
                characterLimit: userCharacterLimit,
                lineLimit: userLineLimit
            )
        case .assistant:
            return truncated(
                cleanAssistantText(rawContent),
                characterLimit: assistantCharacterLimit,
                lineLimit: assistantLineLimit
            )
        }
    }

    private static func formattedStructuredTranscript(from rawContent: String, maxSegments: Int?) -> String? {
        if let json = parseJSON(rawContent) {
            let result = extractSegments(from: json)
            if result.recognized {
                return format(limitedSegments(result.segments, maxSegments: maxSegments))
            }
        }

        var recognized = false
        var segments: [TranscriptSegment] = []

        for line in rawContent.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("{"), trimmedLine.hasSuffix("}"),
                  let json = parseJSON(trimmedLine) else {
                continue
            }

            let result = extractSegments(from: json)
            if result.recognized {
                recognized = true
                segments.append(contentsOf: result.segments)
            }
        }

        guard recognized else { return nil }
        return format(limitedSegments(segments, maxSegments: maxSegments))
    }

    private static func looksLikeStructuredSessionContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return false }
        return trimmed.contains("\"message\"") ||
            trimmed.contains("\"choices\"") ||
            trimmed.contains("\"toolCall\"") ||
            trimmed.contains("\"toolResult\"") ||
            trimmed.contains("\"thinkingSignature\"") ||
            trimmed.contains("\"skillsSnapshot\"")
    }

    private static func parseJSON(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func extractSegments(from json: Any) -> (recognized: Bool, segments: [TranscriptSegment]) {
        if let array = json as? [Any] {
            var recognized = false
            var segments: [TranscriptSegment] = []

            for item in array {
                let result = extractSegments(from: item)
                recognized = recognized || result.recognized
                segments.append(contentsOf: result.segments)
            }

            return (recognized, segments)
        }

        guard let object = json as? [String: Any] else {
            return (false, [])
        }

        if let message = object["message"] as? [String: Any] {
            return (true, extractMessageSegments(from: message))
        }

        if let choices = object["choices"] as? [[String: Any]] {
            var segments: [TranscriptSegment] = []
            for choice in choices {
                if let message = choice["message"] as? [String: Any] {
                    segments.append(contentsOf: extractMessageSegments(from: message))
                }
                if let delta = choice["delta"] as? [String: Any] {
                    segments.append(contentsOf: extractMessageSegments(from: delta, defaultRole: .assistant))
                }
            }
            return (true, segments)
        }

        if object["role"] is String && object.keys.contains("content") {
            return (true, extractMessageSegments(from: object))
        }

        if let type = object["type"] as? String, isKnownOpenClawRecordType(type) {
            return (true, [])
        }

        if looksLikeOpenClawSessionIndex(object) {
            return (true, [])
        }

        return (false, [])
    }

    private static func extractMessageSegments(
        from message: [String: Any],
        defaultRole: TranscriptRole? = nil
    ) -> [TranscriptSegment] {
        let roleValue = message["role"] as? String
        let role: TranscriptRole?

        switch roleValue {
        case "user":
            role = .user
        case "assistant":
            role = .assistant
        case nil:
            role = defaultRole
        default:
            return []
        }

        guard let role else { return [] }

        switch role {
        case .user:
            let text = cleanUserText(extractText(from: message["content"]))
            guard !text.isEmpty else { return [] }
            return [TranscriptSegment(role: .user, text: text)]

        case .assistant:
            var text = cleanAssistantText(extractText(from: message["content"]))
            if text.isEmpty, let errorMessage = message["errorMessage"] as? String {
                text = "Error: \(errorMessage)"
            }
            guard !text.isEmpty else { return [] }
            return [TranscriptSegment(role: .assistant, text: text)]
        }
    }

    private static func extractText(from value: Any?) -> String {
        switch value {
        case let text as String:
            return text

        case let parts as [Any]:
            return parts.compactMap { part in
                if let text = part as? String {
                    return text
                }

                guard let object = part as? [String: Any] else {
                    return nil
                }

                let type = object["type"] as? String
                guard type == nil || type == "text" || type == "input_text" || type == "output_text" else {
                    return nil
                }

                return object["text"] as? String
            }
            .joined(separator: "\n")

        default:
            return ""
        }
    }

    private static func format(_ segments: [TranscriptSegment]) -> String {
        segments.compactMap { segment in
            let label: String
            let characterLimit: Int
            let lineLimit: Int

            switch segment.role {
            case .user:
                label = "User"
                characterLimit = userCharacterLimit
                lineLimit = userLineLimit
            case .assistant:
                label = "Assistant"
                characterLimit = assistantCharacterLimit
                lineLimit = assistantLineLimit
            }

            let text = truncated(segment.text, characterLimit: characterLimit, lineLimit: lineLimit)
            guard !text.isEmpty else { return nil }
            return "\(label): \(text)"
        }
        .joined(separator: "\n\n")
    }

    private static func limitedSegments(_ segments: [TranscriptSegment], maxSegments: Int?) -> [TranscriptSegment] {
        guard let maxSegments, maxSegments > 0, segments.count > maxSegments else {
            return segments
        }
        return Array(segments.suffix(maxSegments))
    }

    private static func cleanUserText(_ text: String) -> String {
        var cleaned = cleanCommonText(text)

        if let marker = cleaned.range(
            of: "[Current message - respond to this]",
            options: [.caseInsensitive]
        ) {
            cleaned = String(cleaned[marker.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        cleaned = strippingLeadingRolePrefix(from: cleaned, prefixes: ["User:", "Human:"])
        cleaned = cleaned
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[message_id:") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if isSyntheticSystemPrompt(cleaned) {
            return ""
        }

        return cleaned
    }

    private static func cleanAssistantText(_ text: String) -> String {
        strippingLeadingRolePrefix(
            from: cleanCommonText(text),
            prefixes: ["Assistant:", "Claw:"]
        )
    }

    private static func cleanCommonText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("[[reply") {
            guard let markerEnd = cleaned.range(of: "]]") else {
                return ""
            }
            cleaned = String(cleaned[markerEnd.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleaned
    }

    private static func strippingLeadingRolePrefix(from text: String, prefixes: [String]) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in prefixes where cleaned.localizedCaseInsensitiveContains(prefix) {
            guard cleaned.lowercased().hasPrefix(prefix.lowercased()) else { continue }
            cleaned = String(cleaned.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        return cleaned
    }

    private static func truncated(_ text: String, characterLimit: Int, lineLimit: Int) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return "" }

        var didTruncate = false
        let lines = result.components(separatedBy: .newlines)
        if lines.count > lineLimit {
            result = lines.prefix(lineLimit).joined(separator: "\n")
            didTruncate = true
        }

        if result.count > characterLimit {
            let endIndex = result.index(result.startIndex, offsetBy: characterLimit)
            result = String(result[..<endIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            didTruncate = true
        }

        if didTruncate {
            result += "\n... [truncated]"
        }

        return result
    }

    private static func isKnownOpenClawRecordType(_ type: String) -> Bool {
        [
            "session",
            "model_change",
            "thinking_level_change",
            "custom",
            "custom_message",
            "message",
        ].contains(type)
    }

    private static func looksLikeOpenClawSessionIndex(_ object: [String: Any]) -> Bool {
        object.values.contains { value in
            guard let session = value as? [String: Any] else { return false }
            return session["sessionFile"] is String &&
                (session["deliveryContext"] != nil || session["skillsSnapshot"] != nil)
        }
    }

    private static func isSyntheticSystemPrompt(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.hasPrefix("system:") &&
            (lowercased.contains("gateway restart") ||
             lowercased.contains("read heartbeat") ||
             lowercased.contains("current time:"))
    }

    private static func sessionCandidates(from rawIndex: String) -> [SessionCandidate] {
        guard let regex = try? NSRegularExpression(
            pattern: #""sessionFile"\s*:\s*"((?:\\.|[^"\\])+)""#,
            options: []
        ) else {
            return []
        }

        let matches = regex.matches(
            in: rawIndex,
            options: [],
            range: NSRange(rawIndex.startIndex..<rawIndex.endIndex, in: rawIndex)
        )

        return matches.compactMap { match in
            guard let pathRange = Range(match.range(at: 1), in: rawIndex) else { return nil }
            let sessionFile = unescapedJSONString(String(rawIndex[pathRange]))
            let context = contextAround(match: match, in: rawIndex)

            return SessionCandidate(
                sessionFile: sessionFile,
                updatedAt: lastNumber(for: #""updatedAt"\s*:\s*([0-9]+)"#, in: context) ?? 0,
                metadata: context
            )
        }
    }

    private static func fallbackSessionCandidates(in sessionsDirectory: URL) -> [SessionCandidate] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files.compactMap { url in
            guard isPrimarySessionFile(url.lastPathComponent) else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            return SessionCandidate(
                sessionFile: url.path,
                updatedAt: values?.contentModificationDate?.timeIntervalSince1970 ?? 0,
                metadata: ""
            )
        }
    }

    private static func contextAround(match: NSTextCheckingResult, in text: String) -> String {
        let utf16Count = text.utf16.count
        let start = max(0, match.range.location - 6000)
        let end = min(utf16Count, match.range.location + match.range.length + 2500)
        guard start < end,
              let range = Range(NSRange(location: start, length: end - start), in: text) else {
            return ""
        }
        return String(text[range])
    }

    private static func lastNumber(for pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )

        guard let match = matches.last,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Double(text[range])
    }

    private static func unescapedJSONString(_ rawValue: String) -> String {
        let quotedValue = "\"\(rawValue)\""
        if let data = quotedValue.data(using: .utf8),
           let value = try? JSONSerialization.jsonObject(with: data) as? String {
            return value
        }

        return rawValue
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func resolvedSessionURL(
        from path: String,
        homeDirectory: String,
        sessionsDirectory: URL
    ) -> URL {
        if path.hasPrefix("~/") {
            return URL(fileURLWithPath: homeDirectory)
                .appendingPathComponent(String(path.dropFirst(2)))
        }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        return sessionsDirectory.appendingPathComponent(path)
    }

    private static func isPrimarySessionFile(_ filename: String) -> Bool {
        filename.hasSuffix(".jsonl") &&
            !filename.contains(".trajectory") &&
            !filename.contains(".checkpoint.") &&
            !filename.contains(".reset.") &&
            !filename.contains(".deleted.") &&
            !filename.contains(".bak")
    }

    private static func isBackgroundSession(_ candidate: SessionCandidate) -> Bool {
        if URL(fileURLWithPath: candidate.sessionFile)
            .lastPathComponent
            .lowercased()
            .contains("heartbeat") {
            return true
        }

        return ["channel", "provider", "surface", "label", "chatType"].contains { key in
            stringValues(for: key, in: candidate.metadata).contains {
                $0.localizedCaseInsensitiveContains("heartbeat")
            }
        }
    }

    private static func stringValues(for key: String, in text: String) -> [String] {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "\"\(escapedKey)\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return unescapedJSONString(String(text[range]))
        }
    }
}
