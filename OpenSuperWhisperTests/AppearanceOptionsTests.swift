import SwiftUI
import XCTest
@testable import OpenSuperWhisper

final class AppearanceOptionsTests: XCTestCase {

    // MARK: - Enums

    func testIndicatorSize_scales() {
        XCTAssertEqual(IndicatorSize.small.scale, 0.85, accuracy: 0.0001)
        XCTAssertEqual(IndicatorSize.medium.scale, 1.0, accuracy: 0.0001)
        XCTAssertEqual(IndicatorSize.large.scale, 1.25, accuracy: 0.0001)
    }

    func testIndicatorSize_unknownRawValue_fallsBackToMedium() {
        XCTAssertEqual(IndicatorSize(stored: "large"), .large)
        XCTAssertEqual(IndicatorSize(stored: "huge"), .medium)
        XCTAssertEqual(IndicatorSize(stored: ""), .medium)
    }

    func testIndicatorBackgroundStyle_unknownRawValue_fallsBackToStandard() {
        XCTAssertEqual(IndicatorBackgroundStyle(stored: "default"), .standard)
        XCTAssertEqual(IndicatorBackgroundStyle(stored: "solid"), .solid)
        XCTAssertEqual(IndicatorBackgroundStyle(stored: "translucent"), .translucent)
        XCTAssertEqual(IndicatorBackgroundStyle(stored: "glass"), .standard)
    }

    func testWindowBackgroundStyle_unknownRawValue_fallsBackToTranslucent() {
        XCTAssertEqual(WindowBackgroundStyle(stored: "system"), .system)
        XCTAssertEqual(WindowBackgroundStyle(stored: "solid"), .solid)
        XCTAssertEqual(WindowBackgroundStyle(stored: "nonsense"), .translucent)
        XCTAssertEqual(WindowBackgroundStyle(stored: ""), .translucent)
    }

    // MARK: - Window background resolution

    func testWindowBaseHex_system_isNil() {
        XCTAssertNil(AppearanceResolver.windowBaseHex(style: .system, customHex: "#112233", scheme: .dark))
    }

    func testWindowBaseHex_translucent_usesTheWindowColor() {
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .translucent, customHex: "#112233", scheme: .light), "#112233")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .translucent, customHex: "", scheme: .dark), "#1D2327")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .translucent, customHex: "", scheme: .light), "#E6EFF6")
    }

    func testWindowBaseHex_solidWithoutCustom_usesPerSchemeDefault() {
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .solid, customHex: "", scheme: .dark), "#1D2327")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .solid, customHex: "", scheme: .light), "#E6EFF6")
    }

    func testWindowBaseHex_solidWithCustom_usesCustomInBothSchemes() {
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .solid, customHex: "#112233", scheme: .dark), "#112233")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .solid, customHex: "112233", scheme: .light), "#112233")
    }

    func testWindowBaseHex_solidWithInvalidCustom_usesPerSchemeDefault() {
        XCTAssertEqual(AppearanceResolver.windowBaseHex(style: .solid, customHex: "banana", scheme: .dark), "#1D2327")
    }

    func testClampedOpacity_staysInRange() {
        XCTAssertEqual(AppearanceResolver.clampedOpacity(0.0), 0.6, accuracy: 0.0001)
        XCTAssertEqual(AppearanceResolver.clampedOpacity(0.6), 0.6, accuracy: 0.0001)
        XCTAssertEqual(AppearanceResolver.clampedOpacity(0.8), 0.8, accuracy: 0.0001)
        XCTAssertEqual(AppearanceResolver.clampedOpacity(1.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(AppearanceResolver.clampedOpacity(7), 1.0, accuracy: 0.0001)
        XCTAssertEqual(AppearanceResolver.clampedOpacity(.nan), 0.8, accuracy: 0.0001)
    }

    func testIsWindowTransparent_onlyTranslucentLetsTheDesktopThrough() {
        XCTAssertFalse(AppearanceResolver.isWindowTransparent(style: .system))
        XCTAssertFalse(AppearanceResolver.isWindowTransparent(style: .solid))
        XCTAssertTrue(AppearanceResolver.isWindowTransparent(style: .translucent))
    }

    // MARK: - Hex resolution

    func testColor_emptyOrInvalidHex_isNil() {
        XCTAssertNil(AppearanceResolver.color(fromHex: ""))
        XCTAssertNil(AppearanceResolver.color(fromHex: "zzz"))
        XCTAssertNotNil(AppearanceResolver.color(fromHex: "#2F7FB8"))
    }
}
