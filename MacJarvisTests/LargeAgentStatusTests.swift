import XCTest
import SwiftUI
@testable import MacJarvis

final class LargeAgentStatusTests: XCTestCase {
    func testInstalledFilteringIgnoresUninstalledAgents() {
        let snapshots = [
            LargeAgentSnapshot(kind: .openClaw, isInstalled: true, status: .idle),
            LargeAgentSnapshot(kind: .hermes, isInstalled: false, status: .error),
        ]

        XCTAssertEqual(snapshots.installedLargeAgents.map(\.kind), [.openClaw])
        XCTAssertEqual(LargeAgentGlobalHealth.from(snapshots), .nominal)
    }

    func testRunningAgentWithStaleSignalsBecomesStuck() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = LargeAgentSnapshot(
            kind: .openClaw,
            isInstalled: true,
            status: .running,
            lastActivityAt: now.addingTimeInterval(-180),
            lastHeartbeatAt: now.addingTimeInterval(-180)
        )

        XCTAssertEqual(snapshot.evaluatingStaleness(now: now).status, .stuck)
    }

    func testIdleAgentWithOldActivityAndFreshHealthStaysIdle() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = LargeAgentSnapshot(
            kind: .openClaw,
            isInstalled: true,
            status: .idle,
            lastActivityAt: now.addingTimeInterval(-3600),
            lastHeartbeatAt: now.addingTimeInterval(-5)
        )

        XCTAssertEqual(snapshot.evaluatingStaleness(now: now).status, .idle)
    }

    func testErrorDominatesGlobalHealthAndInterruptsRotation() {
        let snapshots = [
            LargeAgentSnapshot(kind: .openClaw, isInstalled: true, status: .idle),
            LargeAgentSnapshot(kind: .hermes, isInstalled: true, status: .error),
        ]

        let health = LargeAgentGlobalHealth.from(snapshots)
        XCTAssertEqual(health, .error)
        XCTAssertTrue(health.interruptsRotation)
    }

    func testNoInstalledAgentsIsNeutral() {
        let snapshots = [
            LargeAgentSnapshot(kind: .openClaw, isInstalled: false, status: .unknown),
            LargeAgentSnapshot(kind: .hermes, isInstalled: false, status: .unknown),
        ]

        let health = LargeAgentGlobalHealth.from(snapshots)
        XCTAssertEqual(health, .noInstalled)
        XCTAssertFalse(health.interruptsRotation)
        XCTAssertEqual(health.severity, .neutral)
    }

    func testRecoveryClearsInterruptAfterSuccessfulReadsOrStableDuration() {
        XCTAssertTrue(LargeAgentGlobalHealth.shouldClearInterrupt(successfulReadCount: 2, stableFor: 1))
        XCTAssertTrue(LargeAgentGlobalHealth.shouldClearInterrupt(successfulReadCount: 1, stableFor: 15))
        XCTAssertFalse(LargeAgentGlobalHealth.shouldClearInterrupt(successfulReadCount: 1, stableFor: 14.9))
    }

    func testSeverityOrdering() {
        XCTAssertTrue(LargeAgentSeverity.warning > .active)
        XCTAssertTrue(LargeAgentSeverity.error > .warning)
    }

    func testActiveSeverityUsesPrimaryThemeColor() {
        XCTAssertEqual(LargeAgentSeverity.active.color(theme: .redact), AppTheme.redact.primary)
        XCTAssertEqual(LargeAgentSeverity.active.color(theme: .matrix), AppTheme.matrix.primary)
    }
}
