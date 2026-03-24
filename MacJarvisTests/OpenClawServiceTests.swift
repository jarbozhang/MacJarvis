import XCTest
@testable import MacJarvis

final class OpenClawServiceTests: XCTestCase {

    @MainActor
    func testInitialStatus() {
        let service = OpenClawService()
        XCTAssertEqual(service.status, .unknown)
        XCTAssertTrue(service.messages.isEmpty)
    }

    @MainActor
    func testConnectToInvalidHost_setsStoppedStatus() async {
        let service = OpenClawService()
        await service.connect(host: "127.0.0.1", port: 1)
        XCTAssertEqual(service.status, .stopped)
    }

    @MainActor
    func testAddUserMessage() {
        let service = OpenClawService()
        service.addUserMessage("Hello")
        XCTAssertEqual(service.messages.count, 1)
        XCTAssertEqual(service.messages.first?.role, .user)
        XCTAssertEqual(service.messages.first?.content, "Hello")
    }

    @MainActor
    func testDisconnect_setsStoppedStatus() {
        let service = OpenClawService()
        service.disconnect()
        XCTAssertEqual(service.status, .stopped)
    }

    @MainActor
    func testSendMessage_addsUserMessage() {
        let service = OpenClawService()
        service.sendMessage("test message")
        XCTAssertEqual(service.messages.count, 1)
        XCTAssertEqual(service.messages.first?.role, .user)
        XCTAssertEqual(service.messages.first?.content, "test message")
    }
}
