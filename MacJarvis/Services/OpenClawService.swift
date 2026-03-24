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
    var isStreaming: Bool = false

    private var baseURL: String = ""
    private var authToken: String = ""
    private var agentId: String = "main"
    private var streamTask: Task<Void, Never>?

    // Stable user ID for session persistence across requests
    private let userId = "macjarvis-\(ProcessInfo.processInfo.hostName)"

    /// Test connectivity via /health endpoint (no token cost)
    func connect(host: String, port: Int, token: String = "", agent: String = "main") async {
        baseURL = "http://\(host):\(port)"
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
}
