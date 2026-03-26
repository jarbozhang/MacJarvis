import XCTest
import SwiftUI
@testable import MacJarvis

final class AppThemeTests: XCTestCase {

    func testRedactThemeColors() {
        let t = AppTheme.redact
        XCTAssertEqual(t.primary, Color(hex: 0xFF8E80))
        XCTAssertEqual(t.primaryDim, Color(hex: 0xE2241F))
        XCTAssertEqual(t.secondary, Color(hex: 0xFE7E4F))
        XCTAssertEqual(t.tertiary, Color(hex: 0xFFE792))
        XCTAssertEqual(t.surface, Color(hex: 0x0E0E0E))
        XCTAssertEqual(t.surfaceContainer, Color(hex: 0x1A1919))
        XCTAssertEqual(t.surfaceContainerHigh, Color(hex: 0x201F1F))
        XCTAssertEqual(t.surfaceContainerLow, Color(hex: 0x131313))
        XCTAssertEqual(t.surfaceContainerLowest, Color(hex: 0x000000))
        XCTAssertEqual(t.onSurface, Color(hex: 0xFFFFFF))
        XCTAssertEqual(t.onSurfaceVariant, Color(hex: 0xADAAAA))
        XCTAssertEqual(t.outlineVariant, Color(hex: 0x484847))
        XCTAssertEqual(t.error, Color(hex: 0xFF6E84))
        XCTAssertEqual(t.errorContainer, Color(hex: 0xA70138))
    }

    func testMatrixThemeColors() {
        let t = AppTheme.matrix
        XCTAssertEqual(t.primary, Color(hex: 0x00FFC2))
        XCTAssertEqual(t.primaryDim, Color(hex: 0x00B88A))
        XCTAssertEqual(t.secondary, Color(hex: 0xFFABF3))
        XCTAssertEqual(t.tertiary, Color(hex: 0xC3F400))
        XCTAssertEqual(t.surface, Color(hex: 0x131318))
        XCTAssertEqual(t.surfaceContainer, Color(hex: 0x1F1F24))
        XCTAssertEqual(t.surfaceContainerHigh, Color(hex: 0x2A292F))
        XCTAssertEqual(t.surfaceContainerLow, Color(hex: 0x1B1B20))
        XCTAssertEqual(t.surfaceContainerLowest, Color(hex: 0x0E0E13))
        XCTAssertEqual(t.onSurface, Color(hex: 0xE4E1E9))
        XCTAssertEqual(t.onSurfaceVariant, Color(hex: 0xB9CBC1))
        XCTAssertEqual(t.outlineVariant, Color(hex: 0x3A4A43))
        XCTAssertEqual(t.error, Color(hex: 0xFF0040))
        XCTAssertEqual(t.errorContainer, Color(hex: 0xFF0040))
    }

    func testDefaultThemeIsRedact() {
        XCTAssertEqual(ThemeKey.defaultValue, .redact)
    }

    func testRawValueRoundTrip() {
        for theme in AppTheme.allCases {
            XCTAssertEqual(AppTheme(rawValue: theme.rawValue), theme)
        }
    }

    @MainActor
    func testSettingsDefaultThemeIsRedact() {
        UserDefaults.standard.removeObject(forKey: "currentTheme")
        let settings = SettingsService()
        XCTAssertEqual(settings.currentTheme, .redact)
    }

    @MainActor
    func testSettingsThemePersistence() {
        UserDefaults.standard.removeObject(forKey: "currentTheme")
        let settings = SettingsService()
        settings.currentTheme = .matrix

        let settings2 = SettingsService()
        XCTAssertEqual(settings2.currentTheme, .matrix)

        // cleanup
        UserDefaults.standard.removeObject(forKey: "currentTheme")
    }

    @MainActor
    func testSettingsInvalidThemeRawValue() {
        UserDefaults.standard.set("invalid_theme", forKey: "currentTheme")
        let settings = SettingsService()
        XCTAssertEqual(settings.currentTheme, .redact)

        // cleanup
        UserDefaults.standard.removeObject(forKey: "currentTheme")
    }

    func testFontMethodsExist() {
        let _ = AppTheme.headlineFont(size: 12)
        let _ = AppTheme.bodyFont(size: 12)
        let _ = AppTheme.labelFont(size: 12)
        let _ = AppTheme.monoFont(size: 12)
    }

    func testCardSpacing() {
        XCTAssertEqual(AppTheme.cardSpacing, 8)
    }

    func testAllCasesIterable() {
        XCTAssertEqual(AppTheme.allCases.count, 2)
    }
}
