import XCTest
@testable import MacJarvis

@MainActor
final class TokenServiceClaudeTests: XCTestCase {

    func testParseClaudeStats_todayData() {
        let today = Self.todayString()
        let json = """
        {
          "version": 2,
          "dailyActivity": [
            {"date": "\(today)", "messageCount": 100, "sessionCount": 3}
          ],
          "dailyModelTokens": [
            {"date": "\(today)", "tokensByModel": {"claude-opus-4-6": 5000, "claude-sonnet-4-5": 2000}}
          ]
        }
        """.data(using: .utf8)!

        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalTokens, 7000)
        XCTAssertEqual(result?.sessionCount, 3)
    }

    func testParseClaudeStats_noTodayData() {
        let json = """
        {
          "version": 2,
          "dailyActivity": [
            {"date": "2025-01-01", "messageCount": 50, "sessionCount": 2}
          ],
          "dailyModelTokens": [
            {"date": "2025-01-01", "tokensByModel": {"claude-opus-4-6": 3000}}
          ]
        }
        """.data(using: .utf8)!

        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNil(result)
    }

    func testParseClaudeStats_invalidJSON() {
        let json = "not json".data(using: .utf8)!
        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNil(result)
    }

    func testParseClaudeStats_activityButNoTokens() {
        let today = Self.todayString()
        let json = """
        {
          "version": 2,
          "dailyActivity": [
            {"date": "\(today)", "messageCount": 10, "sessionCount": 1}
          ],
          "dailyModelTokens": []
        }
        """.data(using: .utf8)!

        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalTokens, 0)
        XCTAssertEqual(result?.sessionCount, 1)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
