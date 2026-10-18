import AppKit
import SwiftUI

/// Background of the main window (and, opaque, the settings sheet).
struct AppWindowBackground: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @ObservedObject private var tint = AppearanceStore.shared.tint
    @Environment(\.colorScheme) private var colorScheme
    /// Settings stays readable: the Beluga window color for the scheme, full opacity, no blur,
    /// whatever style the main window uses.
    var opaque = false

    var body: some View {
        if opaque {
            appearance.windowBaseColor(for: colorScheme)
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
