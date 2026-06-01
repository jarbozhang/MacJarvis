import XCTest
@testable import MacJarvis

final class DashboardPageTests: XCTestCase {
    func testFaultOverridesScheduledConsumptionPage() {
        let next = DashboardRotation.nextPage(
            current: .consumption,
            elapsed: 99,
            health: .error,
            hasConsumptionData: true,
            settingsPresented: false,
            recoveryElapsed: nil
        )

        XCTAssertEqual(next, .fault)
    }

    func testHealthyRotationAdvancesStatusConsumptionSystemStatus() {
        let consumption = DashboardRotation.nextPage(
            current: .status,
            elapsed: DashboardRotation.statusDwell,
            health: .nominal,
            hasConsumptionData: true,
            settingsPresented: false,
            recoveryElapsed: nil
        )
        let system = DashboardRotation.nextPage(
            current: consumption,
            elapsed: DashboardRotation.detailDwell,
            health: .nominal,
            hasConsumptionData: true,
            settingsPresented: false,
            recoveryElapsed: nil
        )
        let status = DashboardRotation.nextPage(
            current: system,
            elapsed: DashboardRotation.detailDwell,
            health: .nominal,
            hasConsumptionData: true,
            settingsPresented: false,
            recoveryElapsed: nil
        )

        XCTAssertEqual(consumption, .consumption)
        XCTAssertEqual(system, .system)
        XCTAssertEqual(status, .status)
    }

    func testStatusDwellMustElapseBeforeRotation() {
        let next = DashboardRotation.nextPage(
            current: .status,
            elapsed: DashboardRotation.statusDwell - 1,
            health: .nominal,
            hasConsumptionData: true,
            settingsPresented: false,
            recoveryElapsed: nil
        )

        XCTAssertEqual(next, .status)
    }

    func testSettingsFreezeRotation() {
        let next = DashboardRotation.nextPage(
            current: .status,
            elapsed: 999,
            health: .nominal,
            hasConsumptionData: true,
            settingsPresented: true,
            recoveryElapsed: nil
        )

        XCTAssertEqual(next, .status)
    }

    func testRecoveryKeepsStatusForRecoveryDwell() {
        let next = DashboardRotation.nextPage(
            current: .system,
            elapsed: 999,
            health: .nominal,
            hasConsumptionData: true,
            settingsPresented: false,
            recoveryElapsed: DashboardRotation.recoveryStatusDwell - 1
        )

        XCTAssertEqual(next, .status)
    }
}
