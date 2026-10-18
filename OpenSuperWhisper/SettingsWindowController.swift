import AppKit
import Combine
import SwiftUI

/// Identifiers that tell the app's own windows apart from the main (WindowGroup) window.
enum WindowIdentifier: String {
    case settings = "beluga.settings"

    /// Windows that are never the main window, even though they look like ordinary titled windows.
    static let nonMain: Set<String> = [WindowIdentifier.settings.rawValue]
}

/// Owns the Settings window: one AppKit-managed, always opaque NSWindow hosting the SwiftUI view.
/// Calling `show()` again brings the existing window to the front instead of making a second one.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController(makeContent: {
        configure(NSHostingController(rootView: SettingsView()))
    })

    /// The window owns the size: the hosting controller must not resize it to the SwiftUI ideal size
    /// or replace the window's minimum size with the view's own.
    static func configure<Content: View>(_ host: NSHostingController<Content>) -> NSHostingController<Content> {
        host.sizingOptions = []
        return host
    }

    private let makeContent: @MainActor () -> NSViewController
    private var window: NSWindow?
    private var appearanceObserver: AnyCancellable?
    private var effectiveAppearanceObserver: NSKeyValueObservation?

    init(makeContent: @escaping @MainActor () -> NSViewController) {
        self.makeContent = makeContent
        super.init()
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        NSApplication.shared.setActivationPolicy(.regular)
        let window = ensureWindow()
        Self.enforceMinimumSize(of: window)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func ensureWindow() -> NSWindow {
        if let window { return window }
        let window = Self.makeWindow(contentViewController: makeContent())
        window.delegate = self
        window.setFrameAutosaveName("BelugaSettingsWindow")
        if !window.setFrameUsingName("BelugaSettingsWindow") { window.center() }
        // A frame saved by an older build may be smaller than the minimum.
        Self.enforceMinimumSize(of: window)
        self.window = window
        Self.applyBackground(to: window, store: AppearanceStore.shared)

        // Window color changes (custom color) and light/dark flips repaint the window itself,
        // so nothing unpainted shows behind the SwiftUI content.
        // objectWillChange fires before the value lands, so hop to the next main-queue turn.
        appearanceObserver = AppearanceStore.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let window = self?.window else { return }
                Self.applyBackground(to: window, store: AppearanceStore.shared)
            }
        effectiveAppearanceObserver = window.observe(\.effectiveAppearance, options: [.new]) { window, _ in
            MainActor.assumeIsolated {
                Self.applyBackground(to: window, store: AppearanceStore.shared)
            }
        }
        return window
    }

    func windowForTesting() -> NSWindow { ensureWindow() }

    /// The window itself: titled with a transparent title bar (the sidebar runs up to the top edge),
    /// resizable, opaque, and tagged so `AppDelegate.isMainAppWindow` never mistakes it for the main window.
    static func makeWindow(contentViewController: NSViewController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsWindowMetrics.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.contentViewController = contentViewController
        window.setContentSize(SettingsWindowMetrics.defaultSize)
        window.contentMinSize = SettingsWindowMetrics.minSize
        window.identifier = NSUserInterfaceItemIdentifier(WindowIdentifier.settings.rawValue)
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        return window
    }

    /// Re-asserts the minimum on the NSWindow and grows the window if it is currently smaller.
    static func enforceMinimumSize(of window: NSWindow) {
        window.contentMinSize = SettingsWindowMetrics.minSize
        let content = window.contentRect(forFrameRect: window.frame).size
        let clamped = SettingsWindowMetrics.clampedContentSize(content)
        if clamped != content { window.setContentSize(clamped) }
    }

    /// Belt and braces next to `contentMinSize`: a live resize can never go below the minimum.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let content = sender.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize)).size
        let clamped = SettingsWindowMetrics.clampedContentSize(content)
        return sender.frameRect(forContentRect: NSRect(origin: .zero, size: clamped)).size
    }

    /// Paints the window with the Beluga window color for its current light or dark appearance, fully
    /// opaque. Settings never depends on the main window's style and never uses a macOS system color.
    static func applyBackground(to window: NSWindow, store: AppearanceStore) {
        let isDark = window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let hex = store.windowBaseHex(for: isDark ? .dark : .light)
        window.isOpaque = true
        window.backgroundColor = ColorHex.nsColor(from: hex) ?? .black
    }
}
