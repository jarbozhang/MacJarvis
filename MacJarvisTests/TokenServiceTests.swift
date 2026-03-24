import XCTest
import SQLite3
@testable import MacJarvis

final class TokenServiceTests: XCTestCase {

    var testDbPath: String!

    override func setUp() {
        super.setUp()
        testDbPath = NSTemporaryDirectory() + "test_codex_\(UUID().uuidString).sqlite"
        createTestDatabase()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testDbPath)
        super.tearDown()
    }

    private func createTestDatabase() {
        var db: OpaquePointer?
        guard sqlite3_open(testDbPath, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE threads (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            tokens_used INTEGER NOT NULL DEFAULT 0,
            model_provider TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """
        sqlite3_exec(db, createSQL, nil, nil, nil)

        let now = Int(Date().timeIntervalSince1970)
        let inserts = [
            "INSERT INTO threads VALUES ('t1', 'Test 1', 50000, 'openai', \(now), \(now));",
            "INSERT INTO threads VALUES ('t2', 'Test 2', 30000, 'openai', \(now), \(now));",
            "INSERT INTO threads VALUES ('t3', 'Test 3', 20000, 'openai', \(now), \(now));"
        ]
        for sql in inserts {
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    func testFetchCodexUsage_returnsCorrectTotals() {
        let usage = TokenService.queryCodexDatabase(at: testDbPath)
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?.totalTokens, 100000)
        XCTAssertEqual(usage?.sessionCount, 3)
    }

    func testFetchCodexUsage_invalidPath() {
        let usage = TokenService.queryCodexDatabase(at: "/nonexistent/path.sqlite")
        XCTAssertNil(usage)
    }

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
