import XCTest
@testable import MacJarvis

final class DisplayManagerTests: XCTestCase {

    func testMatchesTargetResolution_exact() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 800, height: 480))
    }

    func testMatchesTargetResolution_withinTolerance() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 860, height: 500))
    }

    func testMatchesTargetResolution_outsideTolerance() {
        XCTAssertFalse(DisplayManager.matchesTargetResolution(width: 1920, height: 1080))
    }

    func testMatchesTargetResolution_lowerBound() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 730, height: 440))
    }

    func testMatchesTargetResolution_belowLowerBound() {
        XCTAssertFalse(DisplayManager.matchesTargetResolution(width: 600, height: 400))
    }
}
