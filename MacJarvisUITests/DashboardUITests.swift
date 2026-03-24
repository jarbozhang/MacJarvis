import XCTest

final class DashboardUITests: MacJarvisUITestBase {

    func testDashboardShowsAllCards() {
        XCTAssertTrue(app.otherElements["tokenCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["clawStatusCard"].exists)
        XCTAssertTrue(app.otherElements["clockCard"].exists)
    }

    func testTokenCardShowsTestData() {
        let tokenCard = app.otherElements["tokenCard"]
        XCTAssertTrue(tokenCard.waitForExistence(timeout: 5))
        XCTAssertTrue(tokenCard.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '125.0K'")
        ).count > 0)
    }

    func testClawStatusShowsUnknownOnLaunch() {
        let statusLabel = app.staticTexts["clawStatusLabel"]
        XCTAssertTrue(statusLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(statusLabel.label, "UNKNOWN")
    }
}
