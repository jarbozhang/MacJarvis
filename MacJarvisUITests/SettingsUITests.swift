import XCTest

final class SettingsUITests: MacJarvisUITestBase {

    func testOpenAndCloseSettings() {
        let gear = app.buttons["settingsButton"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        gear.click()

        let hostInput = app.textFields["hostInput"]
        XCTAssertTrue(hostInput.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["reconnectButton"].exists)

        app.buttons["closeButton"].click()

        // Popover should dismiss
        XCTAssertFalse(hostInput.waitForExistence(timeout: 2))
    }

    func testModifyHostAndReconnect() {
        app.buttons["settingsButton"].click()

        let hostInput = app.textFields["hostInput"]
        XCTAssertTrue(hostInput.waitForExistence(timeout: 3))

        hostInput.click()
        hostInput.typeKey("a", modifierFlags: .command)
        hostInput.typeText("100.67.1.75")

        app.buttons["reconnectButton"].click()
        app.buttons["closeButton"].click()

        // After failed connection, status should change to OFFLINE
        let statusLabel = app.staticTexts["clawStatusLabel"]
        let predicate = NSPredicate(format: "label == 'OFFLINE'")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: statusLabel)
        wait(for: [expectation], timeout: 15)
    }
}
