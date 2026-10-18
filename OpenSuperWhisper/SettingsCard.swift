import SwiftUI

/// The card behind each group of settings: the derived card color, fully opaque (Settings never
/// shows the desktop through), with a 1pt border. Content renders in the scheme that suits the
/// card color, so a Paper card in dark mode still has dark text.
struct SettingsCardModifier: ViewModifier {
    @ObservedObject private var appearance = AppearanceStore.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let surfaces = appearance.surfaces(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 12)
        content
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.colorScheme, SurfacePalette.isLightCard(surfaces.card) ? .light : .dark)
            .background(ColorHex.color(from: surfaces.card) ?? .clear)
            .overlay(shape.stroke(ColorHex.color(from: surfaces.border) ?? .clear, lineWidth: 1))
            .clipShape(shape)
    }
}

extension View {
    func settingsCard() -> some View {
        modifier(SettingsCardModifier())
    }
}

/// A recessed field or row inside a settings card: the derived panel color, opaque, with a 1pt border.
/// A selected row (the chosen model) gets an accent border instead.
struct SettingsInsetModifier: ViewModifier {
    var selected = false
    var cornerRadius: CGFloat = 8
    @ObservedObject private var appearance = AppearanceStore.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let surfaces = appearance.surfaces(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background(ColorHex.color(from: surfaces.panel) ?? .clear)
            .overlay(
                shape.stroke(
                    selected ? appearance.accent : (ColorHex.color(from: surfaces.border) ?? .clear),
                    lineWidth: selected ? 1.5 : 1
                )
            )
            .clipShape(shape)
    }
}

extension View {
    func settingsInset(selected: Bool = false, cornerRadius: CGFloat = 8) -> some View {
        modifier(SettingsInsetModifier(selected: selected, cornerRadius: cornerRadius))
    }
}
