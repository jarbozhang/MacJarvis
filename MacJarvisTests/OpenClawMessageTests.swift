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
}
