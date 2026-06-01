import XCTest
import SQLite3
@testable import MacJarvis

final class HermesServiceTests: XCTestCase {
    @MainActor
    func testDefaultHermesReportsUninstalled() async {
        let home = makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let service = HermesService(homeDirectory: home.path)
        let snapshot = await service.snapshot(now: Date())

        XCTAssertEqual(snapshot.kind, .hermes)
        XCTAssertFalse(snapshot.isInstalled)
    }

    @MainActor
    func testFixtureSnapshotCanReportHealthyHermes() async {
        let now = Date(timeIntervalSince1970: 500)
        let service = HermesService()
        service.fixtureSnapshot = LargeAgentSnapshot(
            kind: .hermes,
            isInstalled: true,
            status: .idle,
            lastHeartbeatAt: now
        )

        let snapshot = await service.snapshot(now: now)
        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertEqual(snapshot.status, .idle)
    }

    func testPublicHermesHostsAreNotPrivateOrLocal() {
        XCTAssertTrue(HermesService.isPrivateOrLocalHost("127.0.0.1"))
        XCTAssertTrue(HermesService.isPrivateOrLocalHost("10.0.1.5"))
        XCTAssertTrue(HermesService.isPrivateOrLocalHost("172.16.1.1"))
        XCTAssertTrue(HermesService.isPrivateOrLocalHost("192.168.1.9"))
        XCTAssertFalse(HermesService.isPrivateOrLocalHost("example.com"))
        XCTAssertFalse(HermesService.isPrivateOrLocalHost("8.8.8.8"))
    }

    func testHermesSnapshotReadsLocalGatewayState() {
        let home = makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let hermes = home.appendingPathComponent(".hermes")
        try! FileManager.default.createDirectory(at: hermes, withIntermediateDirectories: true)
        writeJSON([
            "gateway_state": "running",
            "active_agents": 0,
            "updated_at": "2026-06-01T04:01:44.902086+00:00",
            "platforms": [
                "weixin": [
                    "state": "connected",
                    "updated_at": "2026-06-01T04:01:44.901556+00:00",
                ],
            ],
        ], to: hermes.appendingPathComponent("gateway_state.json"))

        let snapshot = HermesService.snapshot(homeDirectory: home.path, now: Date(timeIntervalSince1970: 1_780_275_000))

        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertEqual(snapshot.status, .idle)
        XCTAssertEqual(snapshot.detail, "weixin connected")
        XCTAssertNotNil(snapshot.lastHeartbeatAt)
    }

    func testHermesSnapshotSummarizesStateDatabaseTokens() {
        let home = makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let hermes = home.appendingPathComponent(".hermes")
        try! FileManager.default.createDirectory(at: hermes, withIntermediateDirectories: true)
        writeJSON(["gateway_state": "running"], to: hermes.appendingPathComponent("gateway_state.json"))
        createHermesStateDatabase(at: hermes.appendingPathComponent("state.db"))

        let snapshot = HermesService.snapshot(homeDirectory: home.path, now: Date(timeIntervalSince1970: 1_780_275_000))

        XCTAssertEqual(snapshot.tokenSummary?.inputTokens, 1_200)
        XCTAssertEqual(snapshot.tokenSummary?.outputTokens, 340)
        XCTAssertEqual(snapshot.tokenSummary?.totalTokens, 1_590)
        XCTAssertEqual(snapshot.tokenSummary?.cost ?? 0, 0.42, accuracy: 0.0001)
    }

    private func makeTemporaryHome() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MacJarvisHermesTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeJSON(_ object: [String: Any], to url: URL) {
        let data = try! JSONSerialization.data(withJSONObject: object)
        try! data.write(to: url)
    }

    private func createHermesStateDatabase(at url: URL) {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let createSQL = """
            CREATE TABLE sessions (
                id TEXT PRIMARY KEY,
                input_tokens INTEGER DEFAULT 0,
                output_tokens INTEGER DEFAULT 0,
                cache_read_tokens INTEGER DEFAULT 0,
                cache_write_tokens INTEGER DEFAULT 0,
                reasoning_tokens INTEGER DEFAULT 0,
                estimated_cost_usd REAL,
                actual_cost_usd REAL,
                started_at REAL NOT NULL,
                ended_at REAL
            );
        """
        XCTAssertEqual(sqlite3_exec(db, createSQL, nil, nil, nil), SQLITE_OK)

        let insertSQL = """
            INSERT INTO sessions (
                id, input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
                reasoning_tokens, estimated_cost_usd, actual_cost_usd, started_at, ended_at
            ) VALUES
                ('a', 1000, 300, 20, 10, 5, 0.20, NULL, 1780275000, 1780275100),
                ('b', 200, 40, 15, 0, 0, 0.10, 0.22, 1780275200, NULL);
        """
        XCTAssertEqual(sqlite3_exec(db, insertSQL, nil, nil, nil), SQLITE_OK)
    }
}
