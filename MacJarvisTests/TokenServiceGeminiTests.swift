import XCTest
@testable import MacJarvis

@MainActor
final class TokenServiceGeminiTests: XCTestCase {

    func testCountGeminiSessions_todayFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("gemini-test-\(UUID())")
        let chatsDir = tmpDir.appendingPathComponent("proj1/chats")
        try FileManager.default.createDirectory(at: chatsDir, withIntermediateDirectories: true)

        let today = Self.todayPrefix()
        let todayFile = chatsDir.appendingPathComponent("session-\(today)-abc123.json")
        let oldFile = chatsDir.appendingPathComponent("session-2025-01-01T10-00-old123.json")

        try "{}".data(using: .utf8)!.write(to: todayFile)
        try "{}".data(using: .utf8)!.write(to: oldFile)

        let result = TokenService.queryGeminiSessions(basePath: tmpDir.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sessionCount, 1)

        try FileManager.default.removeItem(at: tmpDir)
    }

    func testCountGeminiSessions_noFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("gemini-test-\(UUID())")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let result = TokenService.queryGeminiSessions(basePath: tmpDir.path)
        XCTAssertNil(result)

        try FileManager.default.removeItem(at: tmpDir)
    }

    func testCountGeminiSessions_multipleProjects() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("gemini-test-\(UUID())")
        let chats1 = tmpDir.appendingPathComponent("proj1/chats")
        let chats2 = tmpDir.appendingPathComponent("proj2/chats")
        try FileManager.default.createDirectory(at: chats1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: chats2, withIntermediateDirectories: true)

        let today = Self.todayPrefix()
        try "{}".data(using: .utf8)!.write(to: chats1.appendingPathComponent("session-\(today)-s1.json"))
        try "{}".data(using: .utf8)!.write(to: chats2.appendingPathComponent("session-\(today)-s2.json"))
        try "{}".data(using: .utf8)!.write(to: chats2.appendingPathComponent("session-\(today)-s3.json"))

        let result = TokenService.queryGeminiSessions(basePath: tmpDir.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sessionCount, 3)

        try FileManager.default.removeItem(at: tmpDir)
    }

    private static func todayPrefix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm"
        return formatter.string(from: Date())
    }
}
