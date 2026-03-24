import XCTest

final class ChatUITests: MacJarvisUITestBase {

    func testSendTextMessage() {
        let input = app.textFields["chatInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))

        input.click()
        input.typeText("Hello Claw")

        let sendButton = app.buttons["sendButton"]
        XCTAssertTrue(sendButton.isEnabled)
        sendButton.click()

        // Verify user message appears in list
        let messageList = app.scrollViews["messageList"]
        let userMessage = messageList.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Hello Claw'")
        )
        XCTAssertTrue(userMessage.firstMatch.waitForExistence(timeout: 3))

        // Verify input cleared
        XCTAssertEqual(input.value as? String, "")
    }

    func testSendButtonDisabledWhenEmpty() {
        let input = app.textFields["chatInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))

        let sendButton = app.buttons["sendButton"]
        XCTAssertFalse(sendButton.isEnabled)
    }
}
