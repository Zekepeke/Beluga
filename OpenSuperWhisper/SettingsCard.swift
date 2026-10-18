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
