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
    }

    func testFreshPrefs_resolveToBelugaLook() {
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.accentColor.flatMap { ColorHex.hex(from: $0) }, "#2F7FB8")
        XCTAssertEqual(store.indicatorDotColor.flatMap { ColorHex.hex(from: $0) }, "#2F7FB8")
        XCTAssertEqual(ColorHex.hex(from: store.windowBaseColor(for: .dark)!), "#1D2327")
        XCTAssertEqual(ColorHex.hex(from: store.windowBaseColor(for: .light)!), "#E6EFF6")
        XCTAssertTrue(store.isWindowTransparent)
        let dark = store.windowFill(for: .dark)
        XCTAssertEqual(dark.opacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(ColorHex.hex(from: dark.color), "#1D2327")
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

    func testSystem_isOpaqueAndNotTinted() {
        let store = AppearanceStore(defaults: defaults)
        store.windowStyle = .system
        XCTAssertFalse(store.isWindowTransparent)
        XCTAssertEqual(store.windowFill(for: .dark).opacity, 1.0, accuracy: 0.0001)
    }

    func testSystemAndRedOptions_resolveToTodaysLook() {
        let store = AppearanceStore(defaults: defaults)
        store.accentHex = ""
        store.indicatorColorHex = ""
        store.windowStyle = .system
        XCTAssertNil(store.accentColor)
        XCTAssertNil(store.indicatorDotColor)
        XCTAssertNil(store.windowBaseColor(for: .dark))
        XCTAssertFalse(store.isWindowTransparent)
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

        let second = AppearanceStore(defaults: defaults)
        XCTAssertEqual(second.accentHex, "#34C759")
        XCTAssertEqual(second.indicatorColorHex, "")
        XCTAssertEqual(second.indicatorSize, .large)
        XCTAssertEqual(second.indicatorBackground, .translucent)
        XCTAssertEqual(second.windowStyle, .translucent)
        XCTAssertEqual(second.windowColorHex, "#112233")
        XCTAssertEqual(second.windowOpacity, 0.65, accuracy: 0.0001)
    }

    func testResetToDefaults_restoresApprovedDefaults() {
        let store = AppearanceStore(defaults: defaults)
        store.accentHex = ""
        store.indicatorSize = .small
        store.windowStyle = .system
        store.windowOpacity = 0.6
        store.resetToDefaults()
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
}
