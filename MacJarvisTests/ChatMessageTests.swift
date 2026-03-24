import XCTest
@testable import MacJarvis

final class ChatMessageTests: XCTestCase {

    func testUserMessage() {
        let msg = ChatMessage(role: .user, content: "Hello")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertNotNil(msg.id)
    }

    func testAssistantMessage() {
        let msg = ChatMessage(role: .assistant, content: "Hi there")
        XCTAssertEqual(msg.role, .assistant)
    }

    func testClawStatusEquatable() {
        XCTAssertEqual(ClawStatus.running, ClawStatus.running)
        XCTAssertNotEqual(ClawStatus.running, ClawStatus.stopped)
    }

    func testClawStatusLabel() {
        XCTAssertEqual(ClawStatus.running.label, "ONLINE")
        XCTAssertEqual(ClawStatus.stopped.label, "OFFLINE")
        XCTAssertEqual(ClawStatus.error.label, "ERROR")
        XCTAssertEqual(ClawStatus.unknown.label, "UNKNOWN")
    }
}
