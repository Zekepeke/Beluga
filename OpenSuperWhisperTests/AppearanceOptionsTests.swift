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

    func testWindowBackgroundStyle_hasOnlySolidAndTranslucent() {
        XCTAssertEqual(WindowBackgroundStyle.allCases, [.solid, .translucent])
        XCTAssertEqual(WindowBackgroundStyle.defaultValue, .translucent)
    }

    func testWindowBackgroundStyle_savedSystem_readsAsTheDefault() {
        XCTAssertEqual(WindowBackgroundStyle(stored: "system"), .translucent)
        XCTAssertTrue(WindowBackgroundStyle.isRetired(stored: "system"))
        XCTAssertFalse(WindowBackgroundStyle.isRetired(stored: "solid"))
        XCTAssertFalse(WindowBackgroundStyle.isRetired(stored: ""))
    }

    func testWindowBackgroundStyle_unknownRawValue_fallsBackToTranslucent() {
        XCTAssertEqual(WindowBackgroundStyle(stored: "solid"), .solid)
        XCTAssertEqual(WindowBackgroundStyle(stored: "nonsense"), .translucent)
        XCTAssertEqual(WindowBackgroundStyle(stored: ""), .translucent)
    }

    // MARK: - Window background resolution

    func testWindowBaseHex_withoutCustom_followsTheScheme() {
        XCTAssertEqual(AppearanceResolver.windowBaseHex(customHex: "", scheme: .dark), "#161D23")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(customHex: "", scheme: .light), "#E6EFF6")
    }

    func testWindowBaseHex_withCustom_usesCustomInBothSchemes() {
        XCTAssertEqual(AppearanceResolver.windowBaseHex(customHex: "#112233", scheme: .dark), "#112233")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(customHex: "112233", scheme: .light), "#112233")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(customHex: "#aabbcc", scheme: .light), "#AABBCC")
    }

    func testWindowBaseHex_withInvalidCustom_usesPerSchemeDefault() {
        XCTAssertEqual(AppearanceResolver.windowBaseHex(customHex: "banana", scheme: .dark), "#161D23")
        XCTAssertEqual(AppearanceResolver.windowBaseHex(customHex: "banana", scheme: .light), "#E6EFF6")
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
