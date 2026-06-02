import XCTest

final class DashboardUITests: MacJarvisUITestBase {

    func testStatusWallShowsOpenClawWithoutHermesFault() {
        XCTAssertTrue(app.otherElements["statusWall"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["globalStatus"].exists)
        XCTAssertTrue(app.otherElements["largeAgentStatus-openclaw"].exists)
        XCTAssertFalse(app.otherElements["largeAgentStatus-hermes"].exists)
        XCTAssertFalse(app.otherElements["faultInterrupt"].exists)
    }

    func testMissingSmallTokenDataKeepsHealthyLargeAgentStatus() {
        relaunch(fixture: "missing-small-token")

        XCTAssertTrue(app.otherElements["statusWall"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'SYSTEM NOMINAL'")
        ).count > 0)
        XCTAssertTrue(app.otherElements["compactConsumption"].exists)
    }

    func testNoLargeAgentsShowsNeutralStateAndSecondaryStrips() {
        relaunch(fixture: "no-large-agents")

        XCTAssertTrue(app.otherElements["statusWall"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["noLargeAgentsState"].exists)
        XCTAssertTrue(app.otherElements["compactConsumption"].exists)
        XCTAssertTrue(app.otherElements["compactSystem"].exists)
    }

    func testStuckAgentShowsFaultInterrupt() {
        relaunch(fixture: "stuck-openclaw")

        XCTAssertTrue(app.otherElements["faultInterrupt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["faultHeadline"].exists)
        XCTAssertTrue(app.otherElements["largeAgentStatus-openclaw"].exists)
    }

    func testErrorAgentShowsFaultInterrupt() {
        relaunch(fixture: "error-openclaw", page: "system")

        XCTAssertTrue(app.otherElements["faultInterrupt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["systemDetail"].exists)
    }

    func testConsumptionDetailSeparatesLargeAndSmallAgents() {
        relaunch(fixture: "mixed-openclaw-hermes", page: "consumption")

        XCTAssertTrue(app.otherElements["consumptionDetail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'OPENCLAW'")).count > 0)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'HERMES'")).count > 0)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'USAGE ONLY'")).count > 0)
    }

    func testSystemDetailShowsCpuMemoryDisk() {
        relaunch(page: "system")

        XCTAssertTrue(app.otherElements["systemDetail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CPU"].exists)
        XCTAssertTrue(app.staticTexts["MEMORY"].exists)
        XCTAssertTrue(app.staticTexts["DISK"].exists)
    }

    // MARK: - Three-segment strip layout (logo + center detail + right metrics)

    func testStripShowsOpenClawLogoAndCenterDetail() {
        XCTAssertTrue(app.otherElements["largeAgentStatus-openclaw"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["agentLogo-openclaw"].exists)
        XCTAssertTrue(app.staticTexts["agentDetail-openclaw"].exists)
        XCTAssertFalse(app.staticTexts["agentDetail-openclaw"].label.isEmpty)
    }

    func testStripRendersHermesLogoAndDetailInMixedFixture() {
        relaunch(fixture: "mixed-openclaw-hermes")

        XCTAssertTrue(app.otherElements["largeAgentStatus-hermes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["agentLogo-hermes"].exists)
        XCTAssertTrue(app.staticTexts["agentDetail-hermes"].exists)
        XCTAssertTrue(app.otherElements["agentLogo-openclaw"].exists)
        XCTAssertTrue(app.staticTexts["agentDetail-openclaw"].exists)
    }

    func testStripDetailRemainsVisibleOnStuckAgent() {
        relaunch(fixture: "stuck-openclaw")

        XCTAssertTrue(app.otherElements["largeAgentStatus-openclaw"].waitForExistence(timeout: 5))
        let detail = app.staticTexts["agentDetail-openclaw"]
        XCTAssertTrue(detail.exists)
        XCTAssertFalse(detail.label.isEmpty)
    }

    func testStripAccessibilityLabelMentionsStatusLineAndSignal() {
        XCTAssertTrue(app.otherElements["largeAgentStatus-openclaw"].waitForExistence(timeout: 5))
        let label = app.otherElements["largeAgentStatus-openclaw"].label
        XCTAssertTrue(label.contains("OpenClaw"), "label was: \(label)")
        XCTAssertTrue(label.lowercased().contains("signal"), "label was: \(label)")
    }
}
