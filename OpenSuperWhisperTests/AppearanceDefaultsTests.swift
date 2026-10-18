import SwiftUI
import XCTest
@testable import OpenSuperWhisper

@MainActor
final class AppearanceDefaultsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppearanceDefaultsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testFreshPrefs_matchApprovedDefaults() {
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.accentHex, "#2F7FB8")
        XCTAssertEqual(store.indicatorColorHex, "#2F7FB8")
        XCTAssertEqual(store.indicatorSize, .medium)
        XCTAssertEqual(store.indicatorBackground, .standard)
        XCTAssertEqual(store.windowStyle, .translucent)
        XCTAssertEqual(store.windowColorHex, "")
        XCTAssertEqual(store.windowOpacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(store.cardColorHex, "")
    }

    func testFreshPrefs_resolveToBelugaLook() {
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.accentColor.flatMap { ColorHex.hex(from: $0) }, "#2F7FB8")
        XCTAssertEqual(store.indicatorDotColor.flatMap { ColorHex.hex(from: $0) }, "#2F7FB8")
        XCTAssertEqual(ColorHex.hex(from: store.windowBaseColor(for: .dark)), "#161D23")
        XCTAssertEqual(ColorHex.hex(from: store.windowBaseColor(for: .light)), "#E6EFF6")
        XCTAssertTrue(store.isWindowTransparent)
        let dark = store.windowFill(for: .dark)
        XCTAssertEqual(dark.opacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(ColorHex.hex(from: dark.color), "#161D23")
    }

    func testSolid_isAlwaysFullyOpaque() {
        let store = AppearanceStore(defaults: defaults)
        store.windowStyle = .solid
        store.windowOpacity = 0.6
        XCTAssertFalse(store.isWindowTransparent)
        XCTAssertEqual(store.windowFill(for: .dark).opacity, 1.0, accuracy: 0.0001)
        XCTAssertEqual(store.windowFill(for: .light).opacity, 1.0, accuracy: 0.0001)
    }

    func testTranslucent_opacityIsTintStrength() {
        let store = AppearanceStore(defaults: defaults)
        store.windowStyle = .translucent
        store.windowOpacity = 0.65
        XCTAssertTrue(store.isWindowTransparent)
        XCTAssertEqual(store.windowFill(for: .light).opacity, 0.65, accuracy: 0.0001)
        XCTAssertEqual(ColorHex.hex(from: store.windowFill(for: .light).color), "#E6EFF6")
    }

    func testSystemAccentAndRedIndicatorOptions_resolveToTodaysLook() {
        let store = AppearanceStore(defaults: defaults)
        store.accentHex = ""
        store.indicatorColorHex = ""
        XCTAssertNil(store.accentColor)
        XCTAssertNil(store.indicatorDotColor)
    }

    func testWindowColor_isAlwaysABelugaColorInBothStylesAndSchemes() {
        let store = AppearanceStore(defaults: defaults)
        for style in WindowBackgroundStyle.allCases {
            store.windowStyle = style
            XCTAssertEqual(ColorHex.hex(from: store.windowBaseColor(for: .dark)), "#161D23", "\(style)")
            XCTAssertEqual(ColorHex.hex(from: store.windowBaseColor(for: .light)), "#E6EFF6", "\(style)")
            XCTAssertEqual(store.windowBaseHex(for: .dark), "#161D23")
        }
    }

    func testSettingsWindowColor_doesNotDependOnTheMainWindowStyle() {
        // Settings paints windowBaseColor at full opacity (AppWindowBackground opaque).
        let store = AppearanceStore(defaults: defaults)
        store.windowColorHex = "#102A43"
        store.windowStyle = .translucent
        let translucent = (ColorHex.hex(from: store.windowBaseColor(for: .dark)), ColorHex.hex(from: store.windowBaseColor(for: .light)))
        store.windowStyle = .solid
        let solid = (ColorHex.hex(from: store.windowBaseColor(for: .dark)), ColorHex.hex(from: store.windowBaseColor(for: .light)))
        XCTAssertEqual(translucent.0, solid.0)
        XCTAssertEqual(translucent.1, solid.1)
    }

    // MARK: - Retired System option

    func testSavedSystemStyle_readsAsTranslucentAtEightyPercent() {
        defaults.set("system", forKey: AppearanceStore.Keys.windowBackgroundStyle)
        defaults.set(0.65, forKey: AppearanceStore.Keys.windowOpacity)
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.windowStyle, .translucent)
        XCTAssertEqual(store.windowOpacity, 0.8, accuracy: 0.0001)
        XCTAssertTrue(store.isWindowTransparent)
        XCTAssertEqual(store.windowFill(for: .light).opacity, 0.8, accuracy: 0.0001)
    }

    func testSavedSystemStyle_isRewrittenSoItOnlyMigratesOnce() {
        defaults.set("system", forKey: AppearanceStore.Keys.windowBackgroundStyle)
        _ = AppearanceStore(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: AppearanceStore.Keys.windowBackgroundStyle), "translucent")
        let again = AppearanceStore(defaults: defaults)
        again.windowOpacity = 0.7
        XCTAssertEqual(AppearanceStore(defaults: defaults).windowOpacity, 0.7, accuracy: 0.0001)
    }

    func testSavedSystemStyle_keepsACustomWindowColor() {
        defaults.set("system", forKey: AppearanceStore.Keys.windowBackgroundStyle)
        defaults.set("#102A43", forKey: AppearanceStore.Keys.windowBackgroundHex)
        XCTAssertEqual(AppearanceStore(defaults: defaults).windowColorHex, "#102A43")
    }

    func testSavedSolidStyle_isKeptAsIs() {
        defaults.set("solid", forKey: AppearanceStore.Keys.windowBackgroundStyle)
        defaults.set(0.65, forKey: AppearanceStore.Keys.windowOpacity)
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.windowStyle, .solid)
        XCTAssertEqual(store.windowOpacity, 0.65, accuracy: 0.0001)
    }

    func testChanges_persistAcrossInstances() {
        let first = AppearanceStore(defaults: defaults)
        first.accentHex = "#34C759"
        first.indicatorColorHex = ""
        first.indicatorSize = .large
        first.indicatorBackground = .translucent
        first.windowStyle = .translucent
        first.windowColorHex = "#112233"
        first.windowOpacity = 0.65
        first.cardColorHex = "#EEF3F8"

        let second = AppearanceStore(defaults: defaults)
        XCTAssertEqual(second.accentHex, "#34C759")
        XCTAssertEqual(second.indicatorColorHex, "")
        XCTAssertEqual(second.indicatorSize, .large)
        XCTAssertEqual(second.indicatorBackground, .translucent)
        XCTAssertEqual(second.windowStyle, .translucent)
        XCTAssertEqual(second.windowColorHex, "#112233")
        XCTAssertEqual(second.windowOpacity, 0.65, accuracy: 0.0001)
        XCTAssertEqual(second.cardColorHex, "#EEF3F8")
    }

    func testResetToDefaults_restoresApprovedDefaults() {
        let store = AppearanceStore(defaults: defaults)
        store.accentHex = ""
        store.indicatorSize = .small
        store.windowStyle = .solid
        store.windowOpacity = 0.6
        store.cardColorHex = "#2A343D"
        store.resetToDefaults()
        XCTAssertEqual(store.cardColorHex, "")
        XCTAssertEqual(AppearanceStore(defaults: defaults).cardColorHex, "")
        XCTAssertEqual(store.accentHex, "#2F7FB8")
        XCTAssertEqual(store.indicatorSize, .medium)
        XCTAssertEqual(store.windowStyle, .translucent)
        XCTAssertEqual(store.windowOpacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(AppearanceStore(defaults: defaults).windowStyle, .translucent)
    }

    func testCorruptStoredValues_fallBackSafely() {
        defaults.set("huge", forKey: AppearanceStore.Keys.indicatorSize)
        defaults.set("nonsense", forKey: AppearanceStore.Keys.windowBackgroundStyle)
        defaults.set(42.0, forKey: AppearanceStore.Keys.windowOpacity)
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.indicatorSize, .medium)
        XCTAssertEqual(store.windowStyle, .translucent)
        XCTAssertEqual(store.windowOpacity, 1.0, accuracy: 0.0001)
    }

    func testOpacitySetter_clampsToRange() {
        let store = AppearanceStore(defaults: defaults)
        store.windowOpacity = 0.1
        XCTAssertEqual(store.windowOpacity, 0.6, accuracy: 0.0001)
        store.windowOpacity = 3
        XCTAssertEqual(store.windowOpacity, 1.0, accuracy: 0.0001)
    }

    // MARK: - Surfaces

    func testSurfaces_defaultsMatchTheDesign() {
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.surfaces(for: .light).card, "#FFFFFF")
        XCTAssertEqual(store.surfaces(for: .light).panel, "#F2F6FA")
        XCTAssertEqual(store.surfaces(for: .dark).card, "#1F2830")
        XCTAssertEqual(store.surfaces(for: .dark).accentText, "#4A9AD4")
    }

    func testSurfaces_followTheWindowColor() {
        let store = AppearanceStore(defaults: defaults)
        let before = store.surfaces(for: .dark)
        store.windowColorHex = "#102A43"
        XCTAssertNotEqual(store.surfaces(for: .dark).card, before.card)
        XCTAssertEqual(store.surfaces(for: .dark).card, SurfacePalette.resolve(
            windowHex: "#102A43", scheme: .dark, accentHex: "#2F7FB8", card: .matchWindow).card)
    }

    func testSurfaces_customCardOverridesOnlyTheCard() {
        let store = AppearanceStore(defaults: defaults)
        let base = store.surfaces(for: .light)
        store.cardColorHex = "#EEF3F8"
        let custom = store.surfaces(for: .light)
        XCTAssertEqual(custom.card, "#EEF3F8")
        XCTAssertEqual(custom.panel, base.panel)
        XCTAssertEqual(custom.border, base.border)
    }

    func testSurfaces_invalidStoredCardColor_matchesTheWindow() {
        defaults.set("banana", forKey: AppearanceStore.Keys.cardColorHex)
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.surfaces(for: .dark).card, "#1F2830")
    }

    func testSurfaces_useTheAccent() {
        let store = AppearanceStore(defaults: defaults)
        store.accentHex = "#0A3D91"
        XCTAssertGreaterThanOrEqual(
            ColorHex.contrastRatio(store.surfaces(for: .dark).accentText, store.surfaces(for: .dark).card)!, 4.5)
        store.accentHex = "#34C759"
        XCTAssertEqual(store.surfaces(for: .light).accentText, "#34C759")
    }

    func testSurfaceOpacity_translucentIsNinetyTwoPercent_othersAreOpaque() {
        let store = AppearanceStore(defaults: defaults)
        store.windowStyle = .translucent
        XCTAssertEqual(store.surfaceOpacity, 0.92, accuracy: 0.0001)
        store.windowStyle = .solid
        XCTAssertEqual(store.surfaceOpacity, 1, accuracy: 0.0001)
    }

    func testCardSwatches_matchTheBoard() {
        XCTAssertEqual(AppearanceDefaults.cardPresets.map(\.name), ["Paper", "Mist", "Slate", "Ink"])
        XCTAssertEqual(AppearanceDefaults.cardPresets.map(\.hex), ["#FFFFFF", "#EEF3F8", "#2A343D", "#10151A"])
    }
}
