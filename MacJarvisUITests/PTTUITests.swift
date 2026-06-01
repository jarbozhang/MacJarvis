import XCTest

final class PTTUITests: MacJarvisUITestBase {

    func testPTTShowsHoldToTalk() throws {
        throw XCTSkip("PTT controls are no longer part of the default status-wall surface.")
        let pttLabel = app.staticTexts["pttStatusLabel"]
        XCTAssertTrue(pttLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(pttLabel.label, "HOLD TO TALK")
    }

    func testPTTButtonExists() throws {
        throw XCTSkip("PTT controls are no longer part of the default status-wall surface.")
        let pttButton = app.otherElements["pttButton"]
        XCTAssertTrue(pttButton.waitForExistence(timeout: 5))
    }
}
