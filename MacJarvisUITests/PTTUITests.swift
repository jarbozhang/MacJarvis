import XCTest

final class PTTUITests: MacJarvisUITestBase {

    func testPTTShowsHoldToTalk() {
        let pttLabel = app.staticTexts["pttStatusLabel"]
        XCTAssertTrue(pttLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(pttLabel.label, "HOLD TO TALK")
    }

    func testPTTButtonExists() {
        let pttButton = app.otherElements["pttButton"]
        XCTAssertTrue(pttButton.waitForExistence(timeout: 5))
    }
}
