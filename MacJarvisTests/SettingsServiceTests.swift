import XCTest
@testable import MacJarvis

final class SettingsServiceTests: XCTestCase {

    @MainActor
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "openClawHost")
        UserDefaults.standard.removeObject(forKey: "openClawPort")
        UserDefaults.standard.removeObject(forKey: "openClawToken")
        UserDefaults.standard.removeObject(forKey: "openClawAgent")
    }

    @MainActor
    func testDefaultHost() {
        let settings = SettingsService()
        XCTAssertEqual(settings.openClawHost, "127.0.0.1")
    }

    @MainActor
    func testDefaultPort() {
        let settings = SettingsService()
        XCTAssertEqual(settings.openClawPort, 18789)
    }

    @MainActor
    func testDefaultAgent() {
        let settings = SettingsService()
        XCTAssertEqual(settings.openClawAgent, "main")
    }

    @MainActor
    func testPersistence() {
        let settings = SettingsService()
        settings.openClawHost = "192.168.1.100"
        settings.openClawPort = 9999
        settings.openClawToken = "test-token"
        settings.openClawAgent = "jarvis"

        let settings2 = SettingsService()
        XCTAssertEqual(settings2.openClawHost, "192.168.1.100")
        XCTAssertEqual(settings2.openClawPort, 9999)
        XCTAssertEqual(settings2.openClawToken, "test-token")
        XCTAssertEqual(settings2.openClawAgent, "jarvis")
    }
}
