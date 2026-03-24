import XCTest
import SQLite3
@testable import MacJarvis

@MainActor
final class TokenServiceE2ETests: XCTestCase {

    private var tmpDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("macjarvis-e2e-\(UUID())")
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func createCodexDB() -> String {
        let dbPath = tmpDir.appendingPathComponent("codex.sqlite").path
        var db: OpaquePointer?
        sqlite3_open(dbPath, &db)
        let now = Int(Date().timeIntervalSince1970)
        sqlite3_exec(db, """
            CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT NOT NULL, tokens_used INTEGER NOT NULL DEFAULT 0, model_provider TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
            INSERT INTO threads VALUES ('t1', 'Test', 50000, 'openai', \(now), \(now));
            INSERT INTO threads VALUES ('t2', 'Test2', 30000, 'openai', \(now), \(now));
        """, nil, nil, nil)
        sqlite3_close(db)
        return dbPath
    }

    private func createClaudeJSON() -> String {
        let path = tmpDir.appendingPathComponent("claude-stats.json").path
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let json = """
        {
            "version": 2,
            "dailyActivity": [{"date": "\(today)", "messageCount": 50, "sessionCount": 4}],
            "dailyModelTokens": [{"date": "\(today)", "tokensByModel": {"claude-opus-4-6": 12000, "claude-sonnet": 3000}}]
        }
        """
        try! json.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    private func createGeminiDir() -> String {
        let base = tmpDir.appendingPathComponent("gemini-tmp")
        let chats = base.appendingPathComponent("proj1/chats")
        try! FileManager.default.createDirectory(at: chats, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        try! "{}".write(to: chats.appendingPathComponent("session-\(today)T10-00-abc.json"), atomically: true, encoding: .utf8)
        try! "{}".write(to: chats.appendingPathComponent("session-\(today)T11-00-def.json"), atomically: true, encoding: .utf8)
        return base.path
    }

    // MARK: - Tests

    func testFetchAll_updatesAllTools() async {
        let codexPath = createCodexDB()
        let claudePath = createClaudeJSON()
        let geminiPath = createGeminiDir()

        let service = TokenService(codexDbPath: codexPath, claudeStatsPath: claudePath, geminiBasePath: geminiPath)
        service.fetchAll()

        // Wait for Task.detached + MainActor.run to complete
        try? await Task.sleep(for: .seconds(1))

        // Codex
        let codex = service.tools.first(where: { $0.id == "codex" })
        XCTAssertEqual(codex?.totalTokens, 80000)
        XCTAssertEqual(codex?.sessionCount, 2)
        XCTAssertNotNil(codex?.lastUpdated)

        // Claude
        let claude = service.tools.first(where: { $0.id == "claude" })
        XCTAssertEqual(claude?.totalTokens, 15000)
        XCTAssertEqual(claude?.sessionCount, 4)
        XCTAssertNotNil(claude?.lastUpdated)

        // Gemini
        let gemini = service.tools.first(where: { $0.id == "gemini" })
        XCTAssertEqual(gemini?.sessionCount, 2)
        XCTAssertNotNil(gemini?.lastUpdated)
    }

    func testFetchAll_partialDataSources() async {
        let codexPath = createCodexDB()

        let service = TokenService(codexDbPath: codexPath, claudeStatsPath: "/nonexistent/path.json", geminiBasePath: "/nonexistent/dir")
        service.fetchAll()

        try? await Task.sleep(for: .seconds(1))

        // Codex should be updated
        let codex = service.tools.first(where: { $0.id == "codex" })
        XCTAssertEqual(codex?.totalTokens, 80000)

        // Claude and Gemini should remain nil
        let claude = service.tools.first(where: { $0.id == "claude" })
        XCTAssertNil(claude?.totalTokens)
        let gemini = service.tools.first(where: { $0.id == "gemini" })
        XCTAssertNil(gemini?.sessionCount)
    }

    func testFetchAll_corruptClaudeJSON() async {
        let codexPath = createCodexDB()
        let claudePath = tmpDir.appendingPathComponent("corrupt.json").path
        try! "not valid json {{{".write(toFile: claudePath, atomically: true, encoding: .utf8)

        let service = TokenService(codexDbPath: codexPath, claudeStatsPath: claudePath, geminiBasePath: "/nonexistent")
        service.fetchAll()

        try? await Task.sleep(for: .seconds(1))

        // Should not crash, Claude stays nil
        let claude = service.tools.first(where: { $0.id == "claude" })
        XCTAssertNil(claude?.totalTokens)

        // Codex should still work
        let codex = service.tools.first(where: { $0.id == "codex" })
        XCTAssertEqual(codex?.totalTokens, 80000)
    }

    func testFetchAll_emptyGeminiDirectory() async {
        let geminiPath = tmpDir.appendingPathComponent("empty-gemini").path
        try! FileManager.default.createDirectory(atPath: geminiPath, withIntermediateDirectories: true)

        let service = TokenService(codexDbPath: "/nonexistent", claudeStatsPath: "/nonexistent", geminiBasePath: geminiPath)
        service.fetchAll()

        try? await Task.sleep(for: .seconds(1))

        let gemini = service.tools.first(where: { $0.id == "gemini" })
        XCTAssertNil(gemini?.sessionCount)
    }
}
