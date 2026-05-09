import XCTest
@testable import MacJarvis

final class OpenClawMessageTests: XCTestCase {

    @MainActor
    func testSendMessage_whenNotConnected_onlyAddsLocalMessage() {
        let service = OpenClawService()
        // status is .unknown, not .running — message should be added but not sent
        service.sendMessage("hello")
        XCTAssertEqual(service.messages.count, 1)
        XCTAssertEqual(service.messages.first?.content, "hello")
        XCTAssertFalse(service.isStreaming)
    }

    @MainActor
    func testMultipleMessages_maintainOrder() {
        let service = OpenClawService()
        service.addUserMessage("first")
        service.addUserMessage("second")
        service.addUserMessage("third")
        XCTAssertEqual(service.messages.count, 3)
        XCTAssertEqual(service.messages.map(\.content), ["first", "second", "third"])
    }

    func testDisplayContentFromOpenClawJSONL_keepsUserAndAssistantTextOnly() {
        let raw = """
        {"type":"session","version":3,"id":"abc","timestamp":"2026-04-08T10:57:47.040Z"}
        {"type":"message","id":"u1","message":{"role":"user","content":[{"type":"text","text":"[Chat messages since your last reply - for context]\\nUser: 你好你好\\nAssistant: [CONNECTION ERROR]\\n\\n[Current message - respond to this]\\nUser: 帮我看一下飞书群里今天聊了什么"}]}}
        {"type":"message","id":"a1","message":{"role":"assistant","content":[{"type":"thinking","thinking":"hidden reasoning"},{"type":"toolCall","name":"feishu_chat_history","arguments":{"limit":100}},{"type":"text","text":"[[reply_to_current]] 今天群里主要聊了三件事：\\n1. 项目排期需要提前确认。\\n2. 飞书文档权限还没开。"}]}}
        {"type":"message","id":"t1","message":{"role":"toolResult","toolName":"feishu_chat_history","content":[{"type":"text","text":"very noisy raw tool payload"}]}}
        """

        let display = OpenClawSessionFormatter.displayContent(from: raw)

        XCTAssertEqual(display, """
        User: 帮我看一下飞书群里今天聊了什么

        Assistant: 今天群里主要聊了三件事：
        1. 项目排期需要提前确认。
        2. 飞书文档权限还没开。
        """)
        XCTAssertFalse(display.contains("toolCall"))
        XCTAssertFalse(display.contains("toolResult"))
        XCTAssertFalse(display.contains("hidden reasoning"))
        XCTAssertFalse(display.contains("[[reply_to_current]]"))
        XCTAssertFalse(display.contains("CONNECTION ERROR"))
    }

    func testDisplayContentFromOpenClawJSONL_truncatesLongAssistantText() {
        let longLine = String(repeating: "输出", count: 700)
        let raw = """
        {"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"\(longLine)"}]}}
        """

        let display = OpenClawSessionFormatter.displayContent(from: raw)

        XCTAssertTrue(display.hasPrefix("Assistant: 输出"))
        XCTAssertTrue(display.contains("[truncated]"))
        XCTAssertLessThan(display.count, longLine.count)
    }

    func testDisplayContentFromOpenClawJSON_dropsSessionIndexMetadata() {
        let raw = """
        {"agent:main:main":{"sessionId":"c062284d","sessionFile":"/tmp/session.jsonl","deliveryContext":{"channel":"webchat"},"skillsSnapshot":{"prompt":"<available_skills><skill><name>feishu-doc</name></skill></available_skills>"}}}
        """

        let display = OpenClawSessionFormatter.displayContent(from: raw)

        XCTAssertEqual(display, "")
    }

    func testDisplayContentFromPlainText_removesReplyMarkerAndTruncates() {
        let plain = "[[reply_to_current]] " + String(repeating: "hello ", count: 400)

        let display = OpenClawSessionFormatter.displayContent(from: plain)

        XCTAssertFalse(display.contains("[[reply_to_current]]"))
        XCTAssertTrue(display.hasPrefix("hello"))
        XCTAssertTrue(display.contains("[truncated]"))
    }

    func testRecentSessionPreview_loadsLatestSessionFromIndexWithoutMetadataNoise() throws {
        let home = try makeTemporaryOpenClawHome()
        let sessionsURL = sessionsDirectory(in: home)
        let oldSessionURL = sessionsURL.appendingPathComponent("old.jsonl")
        let latestSessionURL = sessionsURL.appendingPathComponent("latest.jsonl")

        try """
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"旧消息"}]}}
        """.write(to: oldSessionURL, atomically: true, encoding: .utf8)

        try """
        {"type":"custom_message","customType":"openclaw.runtime-context","content":"Conversation info with tools and metadata","display":false}
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"[message_id: om_123]\\n刘聪颖: 最近飞书群说了什么"}]}}
        {"type":"message","message":{"role":"assistant","content":[{"type":"thinking","thinking":"hidden"},{"type":"toolCall","name":"feishu_history"},{"type":"text","text":"[[reply_to_current]] 群里主要聊了排期和文档权限。"}]}}
        """.write(to: latestSessionURL, atomically: true, encoding: .utf8)

        try """
        {
          "agent:main:old": {
            "updatedAt": 1000,
            "deliveryContext": { "channel": "webchat" },
            "sessionFile": "old.jsonl",
            "skillsSnapshot": { "prompt": "<available_skills>very noisy tools</available_skills>" }
          },
          "agent:main:latest": {
            "updatedAt": 2000,
            "deliveryContext": { "channel": "feishu" },
            "origin": { "provider": "feishu", "surface": "feishu" },
            "sessionFile": "latest.jsonl",
            "skillsSnapshot": { "prompt": "<available_skills>heartbeat tool name should not make this background</available_skills>" }
          }
        }
        """.write(to: sessionsURL.appendingPathComponent("sessions.json"), atomically: true, encoding: .utf8)

        let preview = OpenClawSessionFormatter.recentSessionPreview(agent: "main", homeDirectory: home.path)

        XCTAssertEqual(canonicalPath(preview?.sessionFile), canonicalPath(latestSessionURL.path))
        XCTAssertEqual(preview?.displayContent, """
        User: 刘聪颖: 最近飞书群说了什么

        Assistant: 群里主要聊了排期和文档权限。
        """)
        XCTAssertFalse(preview?.displayContent.contains("tools") ?? true)
        XCTAssertFalse(preview?.displayContent.contains("toolCall") ?? true)
        XCTAssertFalse(preview?.displayContent.contains("Conversation info") ?? true)
        XCTAssertFalse(preview?.displayContent.contains("message_id") ?? true)
    }

    func testRecentSessionPreview_skipsHeartbeatSessionEvenWhenItIsNewest() throws {
        let home = try makeTemporaryOpenClawHome()
        let sessionsURL = sessionsDirectory(in: home)
        let heartbeatURL = sessionsURL.appendingPathComponent("heartbeat.jsonl")
        let activeURL = sessionsURL.appendingPathComponent("active.jsonl")

        try """
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"read heartbeat"}]}}
        """.write(to: heartbeatURL, atomically: true, encoding: .utf8)

        try """
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"飞书里最新的问题是什么"}]}}
        {"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"最新问题是安卓应用市场上架资料。"}]}}
        """.write(to: activeURL, atomically: true, encoding: .utf8)

        try """
        {
          "agent:main:heartbeat": {
            "updatedAt": 3000,
            "deliveryContext": { "channel": "heartbeat" },
            "sessionFile": "heartbeat.jsonl"
          },
          "agent:main:active": {
            "updatedAt": 2000,
            "deliveryContext": { "channel": "feishu" },
            "sessionFile": "active.jsonl"
          }
        }
        """.write(to: sessionsURL.appendingPathComponent("sessions.json"), atomically: true, encoding: .utf8)

        let preview = OpenClawSessionFormatter.recentSessionPreview(agent: "main", homeDirectory: home.path)

        XCTAssertEqual(canonicalPath(preview?.sessionFile), canonicalPath(activeURL.path))
        XCTAssertEqual(preview?.displayContent, """
        User: 飞书里最新的问题是什么

        Assistant: 最新问题是安卓应用市场上架资料。
        """)
    }

    func testRecentSessionPreview_usesRegexIndexParsingWhenJSONIndexIsNotStrictlyValid() throws {
        let home = try makeTemporaryOpenClawHome()
        let sessionsURL = sessionsDirectory(in: home)
        let activeURL = sessionsURL.appendingPathComponent("active.jsonl")

        try """
        {"type":"message","message":{"role":"user","content":[{"type":"text","text":"最近活跃 session"}]}}
        {"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"可以读取。"}]}}
        """.write(to: activeURL, atomically: true, encoding: .utf8)

        try """
        {
          "agent:main:active": {
            "updatedAt": 2000,
            "badEscape": "\\uD83D",
            "deliveryContext": { "channel": "webchat" },
            "sessionFile": "active.jsonl"
          }
        }
        """.write(to: sessionsURL.appendingPathComponent("sessions.json"), atomically: true, encoding: .utf8)

        let preview = OpenClawSessionFormatter.recentSessionPreview(agent: "main", homeDirectory: home.path)

        XCTAssertEqual(canonicalPath(preview?.sessionFile), canonicalPath(activeURL.path))
        XCTAssertEqual(preview?.displayContent, """
        User: 最近活跃 session

        Assistant: 可以读取。
        """)
    }

    private func makeTemporaryOpenClawHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacJarvisTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: sessionsDirectory(in: home),
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: home)
        }
        return home
    }

    private func sessionsDirectory(in home: URL) -> URL {
        home.appendingPathComponent(".openclaw")
            .appendingPathComponent("agents")
            .appendingPathComponent("main")
            .appendingPathComponent("sessions")
    }

    private func canonicalPath(_ path: String?) -> String? {
        path.map {
            URL(fileURLWithPath: $0)
                .resolvingSymlinksInPath()
                .path
        }
    }
}
