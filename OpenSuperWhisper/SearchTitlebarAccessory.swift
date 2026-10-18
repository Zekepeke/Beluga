import AppKit

/// The search button in the main window's title bar row. A native titlebar accessory, so the
/// click is never lost to the window's drag handling. It does exactly what ⌘F does.
final class SearchTitlebarAccessoryController: NSTitlebarAccessoryViewController {
    override func loadView() {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search in transcriptions")
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "Search in transcriptions"
        button.target = self
        button.action = #selector(search)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 44, height: 32))
        button.frame.origin = NSPoint(x: 8, y: 2)
        container.addSubview(button)
        view = container
        layoutAttribute = .trailing
    }

    @objc private func search() {
        NotificationCenter.default.post(name: .focusSearch, object: nil)
    }

    static func attach(to window: NSWindow) {
        guard !window.titlebarAccessoryViewControllers.contains(where: { $0 is SearchTitlebarAccessoryController }) else { return }
        window.addTitlebarAccessoryViewController(SearchTitlebarAccessoryController())
    }
}
