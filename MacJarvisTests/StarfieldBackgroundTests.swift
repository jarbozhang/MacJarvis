import XCTest
@testable import MacJarvis

final class StarfieldBackgroundTests: XCTestCase {

    func testStarCount() {
        let stars = generateStars(count: 70)
        XCTAssertEqual(stars.count, 70)
    }

    func testThemeColorRatio() {
        let stars = generateStars(count: 1000, seed: 42, themeColorRatio: 0.1)
        let themeColorCount = stars.filter { $0.usesThemeColor }.count
        // With 1000 stars and 10% ratio, expect roughly 100 ± 50
        XCTAssertGreaterThan(themeColorCount, 50)
        XCTAssertLessThan(themeColorCount, 150)
    }

    func testNormalizedCoordinates() {
        let stars = generateStars(count: 100, seed: 99)
        for star in stars {
            XCTAssertGreaterThanOrEqual(star.position.x, 0.0)
            XCTAssertLessThanOrEqual(star.position.x, 1.0)
            XCTAssertGreaterThanOrEqual(star.position.y, 0.0)
            XCTAssertLessThanOrEqual(star.position.y, 1.0)
        }
    }

    func testDeterministicWithSeed() {
        let stars1 = generateStars(count: 50, seed: 123)
        let stars2 = generateStars(count: 50, seed: 123)
        for (a, b) in zip(stars1, stars2) {
            XCTAssertEqual(a.position.x, b.position.x)
            XCTAssertEqual(a.position.y, b.position.y)
            XCTAssertEqual(a.size, b.size)
            XCTAssertEqual(a.usesThemeColor, b.usesThemeColor)
        }
    }
}
