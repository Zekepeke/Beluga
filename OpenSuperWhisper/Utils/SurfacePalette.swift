import SwiftUI

/// Card, panel, border and text colors for the redesign (design/DESIGN.md).
/// Pure: hex in, hex out, so it tests without UserDefaults or AppKit.
///
/// The default window colors resolve to the exact palette from the design board.
/// Any other window color goes through the derivation rule below, which was fitted
/// to reproduce that palette to within a couple of RGB steps.
enum SurfacePalette {
    enum CardOption: Equatable {
        case matchWindow
        case custom(hex: String)
    }

    struct Output: Equatable {
        let card: String
        let panel: String
        let border: String
        /// Dividers. Same value as `border` today, named separately so dividers can diverge later.
        let separator: String
        let sidebar: String
        /// Text on the window.
        let text: String
        let secondaryText: String
        /// Text-sized accent on the window (links, icons). Lifted in dark mode, the accent as is in light mode.
        let accentText: String
        /// Text on the card. Differs from `text` only when a custom card color needs the other scheme's text.
        let cardText: String
        let cardSecondaryText: String
        let cardAccentText: String
    }

    // MARK: - Design values

    private struct Table {
        let card: String
        let panel: String
        let border: String
        let sidebar: String
        let text: String
        let secondaryText: String
    }

    private static let light = Table(card: "#FFFFFF", panel: "#F2F6FA", border: "#D5E0EA", sidebar: "#DCE8F1",
                                     text: "#14202B", secondaryText: "#5B6B7A")
    private static let dark = Table(card: "#1F2830", panel: "#27323B", border: "#2F3C47", sidebar: "#11171B",
                                    text: "#E8EEF3", secondaryText: "#93A3B1")

    /// Designed dark-mode text accent for Beluga blue. HSL lightening alone gives a flatter blue.
    private static let belugaDarkAccentText = "#4A9AD4"
    private static let minimumTextContrast = 4.5
    /// Above this relative luminance a card counts as light.
    private static let lightCardLuminance = 0.4

    // MARK: - Resolve

    static func resolve(windowHex: String, scheme: ColorScheme, accentHex: String, card option: CardOption) -> Output {
        let isDark = scheme == .dark
        let defaultWindow = isDark ? AppearanceDefaults.windowDarkHex : AppearanceDefaults.windowLightHex
        let window = ColorHex.normalized(windowHex) ?? defaultWindow
        let accent = ColorHex.normalized(accentHex) ?? AppearanceDefaults.beluga
        let own = isDark ? dark : light
        let other = isDark ? light : dark

        let derived: (card: String, panel: String, border: String, sidebar: String)
        if window == defaultWindow {
            derived = (own.card, own.panel, own.border, own.sidebar)
        } else {
            derived = derive(window: window, isDark: isDark)
        }

        var card = derived.card
        if case .custom(let hex) = option, let custom = ColorHex.normalized(hex) { card = custom }

        // Text on the card flips to the other scheme's text when a custom card would make it unreadable.
        func readable(_ preferred: String, _ alternative: String) -> String {
            let first = ColorHex.contrastRatio(preferred, card) ?? 0
            if first >= minimumTextContrast { return preferred }
            let second = ColorHex.contrastRatio(alternative, card) ?? 0
            return second > first ? alternative : preferred
        }

        let accentText = isDark ? liftedAccent(accent, on: derived.card) : accent
        let cardIsLight = (ColorHex.relativeLuminance(card) ?? 0) > lightCardLuminance
        let cardAccentText = cardIsLight ? accent : liftedAccent(accent, on: card)

        return Output(
            card: card,
            panel: derived.panel,
            border: derived.border,
            separator: derived.border,
            sidebar: derived.sidebar,
            text: own.text,
            secondaryText: own.secondaryText,
            accentText: accentText,
            cardText: readable(own.text, other.text),
            cardSecondaryText: readable(own.secondaryText, other.secondaryText),
            cardAccentText: cardAccentText
        )
    }

    /// Whether a card color is light enough to need dark text.
    static func isLightCard(_ hex: String) -> Bool {
        (ColorHex.relativeLuminance(hex) ?? 0) > lightCardLuminance
    }

    // MARK: - Derivation rule

    /// HSL offsets from the window color. Hue is kept. Dark mode lifts surfaces above the window,
    /// light mode keeps cards white and darkens the border and sidebar.
    private static func derive(window: String, isDark: Bool) -> (card: String, panel: String, border: String, sidebar: String) {
        guard let w = ColorHex.hsl(from: window) else {
            let own = isDark ? dark : light
            return (own.card, own.panel, own.border, own.sidebar)
        }
        func shifted(_ lightness: Double, saturation: Double = 1) -> String {
            ColorHex.hex(hue: w.hue, saturation: w.saturation * saturation, lightness: w.lightness + lightness)
        }
        if isDark {
            return (card: shifted(0.043), panel: shifted(0.080, saturation: 0.93),
                    border: shifted(0.120, saturation: 0.92), sidebar: shifted(-0.025))
        }
        return (card: "#FFFFFF", panel: ColorHex.mix(window, "#FFFFFF", 0.5) ?? light.panel,
                border: shifted(-0.057, saturation: 0.7), sidebar: shifted(-0.029, saturation: 0.94))
    }

    // MARK: - Accent text

    /// Lightens the accent in HSL until it reaches 4.5:1 on the surface. Fills never use this.
    private static func liftedAccent(_ accent: String, on surface: String) -> String {
        if accent == AppearanceDefaults.beluga, surface == dark.card { return belugaDarkAccentText }
        if (ColorHex.contrastRatio(accent, surface) ?? 0) >= minimumTextContrast { return accent }
        guard let hsl = ColorHex.hsl(from: accent) else { return accent }
        var lightness = hsl.lightness
        while lightness < 1 {
            lightness = min(lightness + 0.01, 1)
            let candidate = ColorHex.hex(hue: hsl.hue, saturation: hsl.saturation, lightness: lightness)
            if (ColorHex.contrastRatio(candidate, surface) ?? 0) >= minimumTextContrast { return candidate }
        }
        return "#FFFFFF"
    }
}
