import XCTest
@testable import MacJarvis

final class LargeAgentStatusServiceTests: XCTestCase {
    @MainActor
    func testPublishIgnoresUninstalledHermes() {
        let service = LargeAgentStatusService()
        service.publish([
            LargeAgentSnapshot(kind: .openClaw, isInstalled: true, status: .running),
            LargeAgentSnapshot(kind: .hermes, isInstalled: false, status: .error),
        ])

        XCTAssertEqual(service.installedAgents.map(\.kind), [.openClaw])
        XCTAssertEqual(service.globalHealth, .active)
    }

    @MainActor
    func testHermesErrorDominatesOpenClawIdle() {
        let service = LargeAgentStatusService()
        service.publish([
            LargeAgentSnapshot(kind: .openClaw, isInstalled: true, status: .idle),
            LargeAgentSnapshot(kind: .hermes, isInstalled: true, status: .error),
        ])

        XCTAssertEqual(service.globalHealth, .error)
    }

    @MainActor
    func testStuckAgentInterrupts() {
        let service = LargeAgentStatusService()
        service.publish([
            LargeAgentSnapshot(kind: .openClaw, isInstalled: true, status: .stuck),
        ])

        XCTAssertEqual(service.globalHealth, .stuck)
        XCTAssertTrue(service.globalHealth.interruptsRotation)
    }

    @MainActor
    func testFixtureProviderIsDeterministic() {
        let now = Date(timeIntervalSince1970: 1000)
        let service = LargeAgentStatusService()
        service.applyFixture(named: "healthy-openclaw", now: now)

        XCTAssertTrue(service.isUsingFixture)
        XCTAssertEqual(service.globalHealth, .nominal)
        XCTAssertEqual(service.installedAgents.map(\.kind), [.openClaw])
        XCTAssertEqual(service.lastRefreshedAt, now)
    }
}
