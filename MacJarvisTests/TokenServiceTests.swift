import XCTest
@testable import MacJarvis

final class TokenServiceTests: XCTestCase {

    func testFormattedTokens_thousands() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: 50000)
        XCTAssertEqual(usage.formattedTokens, "50.0K")
    }

    func testFormattedTokens_millions() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: 1_500_000)
        XCTAssertEqual(usage.formattedTokens, "1.5M")
    }

    func testFormattedTokens_nil() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: nil)
        XCTAssertEqual(usage.formattedTokens, "--")
    }

    // MARK: - formattedActivity

    func testFormattedActivity_withTokens() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: 5000)
        XCTAssertEqual(usage.formattedActivity, "5.0K")
    }

    func testFormattedActivity_withMessageCount() {
        let usage = ToolUsage(id: "test", name: "Test", messageCount: 42)
        XCTAssertEqual(usage.formattedActivity, "42msg")
    }

    func testFormattedActivity_noData() {
        let usage = ToolUsage(id: "test", name: "Test")
        XCTAssertEqual(usage.formattedActivity, "--")
    }

    func testFormattedActivity_tokensOverrideMessages() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: 1000, messageCount: 10)
        XCTAssertEqual(usage.formattedActivity, "1.0K")
    }
}
