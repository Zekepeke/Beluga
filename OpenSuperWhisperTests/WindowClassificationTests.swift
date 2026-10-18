import AppKit
import SwiftUI
import XCTest
@testable import OpenSuperWhisper

@MainActor
final class WindowClassificationTests: XCTestCase {

    // MARK: - Pure rule

    func testTitledPlainWindow_isTheMainWindow() {
        XCTAssertTrue(AppDelegate.isMainAppWindow(isPanel: false, isSheet: false, isTitled: true, identifier: nil))
        XCTAssertTrue(AppDelegate.isMainAppWindow(isPanel: false, isSheet: false, isTitled: true, identifier: "AppWindow-1"))
    }

    func testPanelsSheetsAndUntitledWindows_areNotMain() {
        XCTAssertFalse(AppDelegate.isMainAppWindow(isPanel: true, isSheet: false, isTitled: true, identifier: nil))
        XCTAssertFalse(AppDelegate.isMainAppWindow(isPanel: false, isSheet: true, isTitled: true, identifier: nil))
        XCTAssertFalse(AppDelegate.isMainAppWindow(isPanel: false, isSheet: false, isTitled: false, identifier: nil))
    }

    func testSettingsIdentifier_isNeverMain_evenForATitledPlainWindow() {
        XCTAssertFalse(AppDelegate.isMainAppWindow(
            isPanel: false, isSheet: false, isTitled: true, identifier: WindowIdentifier.settings.rawValue))
    }

    func testSettingsIdentifier_isStable() {
        XCTAssertEqual(WindowIdentifier.settings.rawValue, "beluga.settings")
    }

    // MARK: - The real Settings window

    func testSettingsWindow_isNeverTreatedAsTheMainWindow() {
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertFalse(window is NSPanel)
        XCTAssertFalse(window.isSheet)
        XCTAssertEqual(window.identifier?.rawValue, WindowIdentifier.settings.rawValue)
        XCTAssertFalse(AppDelegate.isMainAppWindow(window))
    }

    func testSettingsWindow_isOpaqueResizableAndSized() {
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        XCTAssertTrue(window.isOpaque)
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertEqual(window.contentMinSize.width, SettingsWindowMetrics.minSize.width)
        XCTAssertEqual(window.contentMinSize.height, SettingsWindowMetrics.minSize.height)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.width, SettingsWindowMetrics.defaultSize.width, accuracy: 1)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.height, SettingsWindowMetrics.defaultSize.height, accuracy: 1)
    }

    func testSettingsWindow_backgroundIsTheBelugaWindowColor() {
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        for (name, hex) in [(NSAppearance.Name.aqua, AppearanceDefaults.windowLightHex), (.darkAqua, AppearanceDefaults.windowDarkHex)] {
            window.appearance = NSAppearance(named: name)
            SettingsWindowController.applyBackground(to: window, store: AppearanceStore(defaults: UserDefaults(suiteName: "SettingsWindowTests-\(UUID().uuidString)")!))
            XCTAssertEqual(ColorHex.hex(from: Color(nsColor: window.backgroundColor)), hex, "\(name)")
            XCTAssertTrue(window.isOpaque)
        }
    }

    func testSettingsWindow_backgroundFollowsACustomWindowColor() {
        let suite = "SettingsWindowTests-\(UUID().uuidString)"
        let store = AppearanceStore(defaults: UserDefaults(suiteName: suite)!)
        store.windowColorHex = "#102A43"
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        window.appearance = NSAppearance(named: .darkAqua)
        SettingsWindowController.applyBackground(to: window, store: store)
        XCTAssertEqual(ColorHex.hex(from: Color(nsColor: window.backgroundColor)), "#102A43")
    }

    func testSettingsWindow_backgroundIgnoresTheMainWindowStyle() {
        let store = AppearanceStore(defaults: UserDefaults(suiteName: "SettingsWindowTests-\(UUID().uuidString)")!)
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        window.appearance = NSAppearance(named: .aqua)
        store.windowStyle = .translucent
        SettingsWindowController.applyBackground(to: window, store: store)
        let translucent = window.backgroundColor
        store.windowStyle = .solid
        SettingsWindowController.applyBackground(to: window, store: store)
        XCTAssertEqual(window.backgroundColor, translucent)
        XCTAssertEqual(window.backgroundColor.alphaComponent, 1, accuracy: 0.0001)
    }

    func testControllerReusesTheSameWindow() {
        let controller = SettingsWindowController(makeContent: { NSViewController() })
        let first = controller.windowForTesting()
        let second = controller.windowForTesting()
        XCTAssertTrue(first === second)
    }

    // MARK: - Minimum size

    func testMinimumSize_isEnforcedOnTheWindow() {
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        XCTAssertEqual(window.contentMinSize, CGSize(width: 820, height: 600))
    }

    func testMinimumSize_survivesASwiftUIHostingController() {
        // The hosting controller's own min size (here a tiny SwiftUI frame) must not replace the window's.
        let host = SettingsWindowController.configure(NSHostingController(rootView: Color.clear.frame(minWidth: 50, minHeight: 50)))
        let window = SettingsWindowController.makeWindow(contentViewController: host)
        window.layoutIfNeeded()
        XCTAssertEqual(window.contentMinSize, CGSize(width: 820, height: 600))
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.width, 820, accuracy: 1)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.height, 600, accuracy: 1)
    }

    func testMinimumSize_isReassertedAndTooSmallWindowsGrow() {
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        window.contentMinSize = CGSize(width: 100, height: 100)
        window.setContentSize(CGSize(width: 400, height: 300))
        SettingsWindowController.enforceMinimumSize(of: window)
        XCTAssertEqual(window.contentMinSize, CGSize(width: 820, height: 600))
        let content = window.contentRect(forFrameRect: window.frame).size
        XCTAssertEqual(content.width, 820, accuracy: 1)
        XCTAssertEqual(content.height, 600, accuracy: 1)
    }

    func testEnforcingTheMinimum_leavesALargerWindowAlone() {
        let window = SettingsWindowController.makeWindow(contentViewController: NSViewController())
        window.setContentSize(CGSize(width: 1100, height: 800))
        SettingsWindowController.enforceMinimumSize(of: window)
        let content = window.contentRect(forFrameRect: window.frame).size
        XCTAssertEqual(content.width, 1100, accuracy: 1)
        XCTAssertEqual(content.height, 800, accuracy: 1)
    }

    func testLiveResize_cannotGoBelowTheMinimum() {
        let controller = SettingsWindowController(makeContent: { NSViewController() })
        let window = controller.windowForTesting()
        let tiny = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 300, height: 200)).size
        let result = controller.windowWillResize(window, to: tiny)
        let content = window.contentRect(forFrameRect: NSRect(origin: .zero, size: result)).size
        XCTAssertEqual(content.width, 820, accuracy: 1)
        XCTAssertEqual(content.height, 600, accuracy: 1)

        let big = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 1200, height: 900)).size
        XCTAssertEqual(controller.windowWillResize(window, to: big), big)
    }

    func testControllerWindow_hasTheControllerAsDelegate() {
        let controller = SettingsWindowController(makeContent: { NSViewController() })
        XCTAssertTrue(controller.windowForTesting().delegate === controller)
    }
}
