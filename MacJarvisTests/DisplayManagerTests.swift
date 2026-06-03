import XCTest
@testable import MacJarvis

final class DisplayManagerTests: XCTestCase {

    func testMatchesTargetResolution_exact() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 800, height: 480))
    }

    func testMatchesTargetResolution_withinTolerance() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 860, height: 500))
    }

    func testShouldUseFullscreen_atTargetSmallScreenWidth() {
        XCTAssertTrue(DisplayManager.shouldUseFullscreen(forWidth: 1280))
    }

    func testShouldUseFullscreen_aboveTargetSmallScreenWidth() {
        XCTAssertFalse(DisplayManager.shouldUseFullscreen(forWidth: 1281))
    }

    func testMatchesTargetResolution_outsideTolerance() {
        XCTAssertFalse(DisplayManager.matchesTargetResolution(width: 1920, height: 1080))
    }

    func testMatchesTargetResolution_lowerBound() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 730, height: 440))
    }

    func testMatchesTargetResolution_smallScreenCandidate() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 600, height: 400))
    }

    // MARK: - Target screen selection

    func testSelectTarget_macBookWithSmallExternal_picksExternal() {
        let screens: [(name: String, width: CGFloat)] = [
            ("Built-in Retina Display", 1512),
            ("Dashboard", 800)
        ]
        XCTAssertEqual(DisplayManager.selectTargetScreenIndex(from: screens), 1)
    }

    func testSelectTarget_macBookOnly_returnsNil() {
        let screens: [(name: String, width: CGFloat)] = [
            ("Built-in Retina Display", 1512)
        ]
        XCTAssertNil(DisplayManager.selectTargetScreenIndex(from: screens))
    }

    func testSelectTarget_macMiniTwoExternalsSmallAndLarge_picksSmall() {
        // Mac mini has no built-in display; both screens are "external".
        // Without this rule, NSScreen.screens.first would land on the main
        // 2560×1440 desktop instead of the 800×480 dashboard.
        let screens: [(name: String, width: CGFloat)] = [
            ("DELL U2720Q", 2560),
            ("Pi 5-inch", 800)
        ]
        XCTAssertEqual(DisplayManager.selectTargetScreenIndex(from: screens), 1)
    }

    func testSelectTarget_macMiniTwoExternalsBothLarge_picksNarrower() {
        let screens: [(name: String, width: CGFloat)] = [
            ("DELL U3818DW", 3840),
            ("HP Z27", 2560)
        ]
        XCTAssertEqual(DisplayManager.selectTargetScreenIndex(from: screens), 1)
    }

    func testSelectTarget_macMiniSingleLarge_picksThatOne() {
        let screens: [(name: String, width: CGFloat)] = [
            ("Studio Display", 2560)
        ]
        XCTAssertEqual(DisplayManager.selectTargetScreenIndex(from: screens), 0)
    }

    func testSelectTarget_chineseBuiltInIsExcluded() {
        let screens: [(name: String, width: CGFloat)] = [
            ("内建视网膜显示器", 1512),
            ("Dashboard", 800)
        ]
        XCTAssertEqual(DisplayManager.selectTargetScreenIndex(from: screens), 1)
    }
}
