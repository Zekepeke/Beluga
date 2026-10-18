import AppKit
import SwiftUI

/// Background of the main window (and, opaque, the settings sheet).
struct AppWindowBackground: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @ObservedObject private var tint = AppearanceStore.shared.tint
    @Environment(\.colorScheme) private var colorScheme
    /// The settings sheet is its own window and stays readable: full opacity, no blur.
    var opaque = false

    var body: some View {
        if opaque {
            // Keeps the sheet's look under System and Translucent.
            appearance.windowBaseColor(for: colorScheme) ?? Color(nsColor: .windowBackgroundColor)
        } else {
            let fill = appearance.windowFill(for: colorScheme)
            ZStack {
                if appearance.windowStyle == .translucent {
                    VisualEffectBackground()
                }
                fill.color.opacity(appearance.windowStyle == .translucent ? tint.opacity : 1)
            }
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
