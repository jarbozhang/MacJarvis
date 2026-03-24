import XCTest
@testable import MacJarvis

@MainActor
final class TokenServiceE2ETests: XCTestCase {

    func testToolUsageFormattedTokens() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: 50000)
        XCTAssertEqual(usage.formattedTokens, "50.0K")
    }

    func testToolUsageFormattedActivity_noData() {
        let usage = ToolUsage(id: "test", name: "Test")
        XCTAssertEqual(usage.formattedActivity, "--")
    }

    func testToolUsageFormattedActivity_messages() {
        let usage = ToolUsage(id: "test", name: "Test", messageCount: 42)
        XCTAssertEqual(usage.formattedActivity, "42msg")
    }
}
