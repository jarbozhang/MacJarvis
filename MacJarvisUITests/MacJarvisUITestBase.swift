import XCTest

class MacJarvisUITestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchApp()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func launchApp(fixture: String = "healthy-openclaw", page: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--uitesting", "--fixture", fixture]
        if let page {
            app.launchArguments += ["--page", page]
        }
        app.launch()
    }

    func relaunch(fixture: String = "healthy-openclaw", page: String? = nil) {
        app.terminate()
        launchApp(fixture: fixture, page: page)
    }
}
