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
        status = .stopped
        connectedAt = nil
    }

    func sendMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
        guard status == .running else { return }

        // Build conversation history (last 20 messages for context)
        let recentMessages = messages.suffix(20).map { msg -> [String: String] in
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

                if let idx = self.messages.firstIndex(where: { $0.id == placeholderId }) {
                    self.messages[idx].content += content
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
        let role: ChatMessage.Role = roleValue == "user" ? .user : .assistant
        let content = extractMessageText(raw["content"])
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
