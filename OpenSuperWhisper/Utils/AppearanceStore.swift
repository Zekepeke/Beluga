import Combine
import SwiftUI

/// Tint strength lives in its own object: it changes on every slider tick, and
/// only the window background should redraw for that, not every view that
/// observes the store.
@MainActor
final class WindowTintModel: ObservableObject {
    private let defaults: UserDefaults

    @Published var opacity: Double {
        didSet {
            let clamped = AppearanceResolver.clampedOpacity(opacity)
            if clamped != opacity {
                opacity = clamped
                return
            }
            defaults.set(opacity, forKey: AppearanceStore.Keys.windowOpacity)
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        opacity = AppearanceResolver.clampedOpacity(
            defaults.object(forKey: AppearanceStore.Keys.windowOpacity) as? Double ?? AppearanceDefaults.windowOpacity
        )
    }
}

/// Shared, observable source for the Appearance options so the indicator,
/// the main window and the Settings tab update live.
@MainActor
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    enum Keys {
        static let accentHex = "appearanceAccentHex"
        static let indicatorColorHex = "indicatorColorHex"
        static let indicatorSize = "indicatorSize"
        static let indicatorBackgroundStyle = "indicatorBackgroundStyle"
        static let windowBackgroundStyle = "windowBackgroundStyle"
        static let windowBackgroundHex = "windowBackgroundHex"
        static let windowOpacity = "windowOpacity"
        static let cardColorHex = "cardColorHex"
    }

    private let defaults: UserDefaults

    /// Empty means the system accent.
    @Published var accentHex: String {
        didSet { defaults.set(accentHex, forKey: Keys.accentHex) }
    }
    /// Empty means the recording red.
    @Published var indicatorColorHex: String {
        didSet { defaults.set(indicatorColorHex, forKey: Keys.indicatorColorHex) }
    }
    @Published var indicatorSize: IndicatorSize {
        didSet { defaults.set(indicatorSize.rawValue, forKey: Keys.indicatorSize) }
    }
    @Published var indicatorBackground: IndicatorBackgroundStyle {
        didSet { defaults.set(indicatorBackground.rawValue, forKey: Keys.indicatorBackgroundStyle) }
    }
    @Published var windowStyle: WindowBackgroundStyle {
        didSet { defaults.set(windowStyle.rawValue, forKey: Keys.windowBackgroundStyle) }
    }
    /// Empty means the per-appearance default solid color.
    @Published var windowColorHex: String {
        didSet { defaults.set(windowColorHex, forKey: Keys.windowBackgroundHex) }
    }
    /// Empty means the card color follows the window color.
    @Published var cardColorHex: String {
        didSet { defaults.set(cardColorHex, forKey: Keys.cardColorHex) }
    }
    /// Tint strength for the translucent window, 60 to 100%.
    let tint: WindowTintModel
    var windowOpacity: Double {
        get { tint.opacity }
        set { tint.opacity = newValue }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accentHex = defaults.string(forKey: Keys.accentHex) ?? AppearanceDefaults.accentHex
        indicatorColorHex = defaults.string(forKey: Keys.indicatorColorHex) ?? AppearanceDefaults.indicatorColorHex
        indicatorSize = IndicatorSize(stored: defaults.string(forKey: Keys.indicatorSize) ?? "")
        indicatorBackground = IndicatorBackgroundStyle(stored: defaults.string(forKey: Keys.indicatorBackgroundStyle) ?? "")
        let storedStyle = defaults.string(forKey: Keys.windowBackgroundStyle) ?? ""
        if WindowBackgroundStyle.isRetired(stored: storedStyle) {
            // The removed System option reads as the default look: Translucent at 80%.
            defaults.set(WindowBackgroundStyle.defaultValue.rawValue, forKey: Keys.windowBackgroundStyle)
            defaults.set(AppearanceDefaults.windowOpacity, forKey: Keys.windowOpacity)
        }
        windowStyle = WindowBackgroundStyle(stored: defaults.string(forKey: Keys.windowBackgroundStyle) ?? "")
        windowColorHex = defaults.string(forKey: Keys.windowBackgroundHex) ?? ""
        cardColorHex = defaults.string(forKey: Keys.cardColorHex) ?? AppearanceDefaults.cardColorHex
        tint = WindowTintModel(defaults: defaults)
    }

    func resetToDefaults() {
        accentHex = AppearanceDefaults.accentHex
        indicatorColorHex = AppearanceDefaults.indicatorColorHex
        indicatorSize = IndicatorSize.defaultValue
        indicatorBackground = IndicatorBackgroundStyle.defaultValue
        windowStyle = WindowBackgroundStyle.defaultValue
        windowColorHex = ""
        cardColorHex = AppearanceDefaults.cardColorHex
        windowOpacity = AppearanceDefaults.windowOpacity
    }

    // MARK: - Resolved values

    /// nil means the system accent.
    var accentColor: Color? { AppearanceResolver.color(fromHex: accentHex) }

    /// nil means today's recording red.
    var indicatorDotColor: Color? { AppearanceResolver.color(fromHex: indicatorColorHex) }

    func windowBaseHex(for scheme: ColorScheme) -> String {
        AppearanceResolver.windowBaseHex(customHex: windowColorHex, scheme: scheme)
    }

    /// The window color for the scheme. Always a Beluga color, never a macOS system color.
    func windowBaseColor(for scheme: ColorScheme) -> Color {
        AppearanceResolver.color(fromHex: windowBaseHex(for: scheme)) ?? .clear
    }

    /// Accent for explicit tints (e.g. toggle styles that name their color).
    var accent: Color { accentColor ?? .accentColor }

    /// The window fill: solid paints the window color fully opaque,
    /// translucent paints it as a tint over the blur.
    func windowFill(for scheme: ColorScheme) -> (color: Color, opacity: Double) {
        let base = windowBaseColor(for: scheme)
        switch windowStyle {
        case .solid: return (base, 1)
        case .translucent: return (base, windowOpacity)
        }
    }

    /// What the indicator's Solid style fills with: the window color at the moment.
    func indicatorSolidColor(for scheme: ColorScheme) -> Color {
        windowBaseColor(for: scheme)
    }

    // MARK: - Surfaces

    var cardOption: SurfacePalette.CardOption {
        ColorHex.normalized(cardColorHex).map { .custom(hex: $0) } ?? .matchWindow
    }

    /// Cards, panels, borders and text for the scheme, derived from the window color.
    /// Pass `card` to preview another card option (for example "Match window" while a custom color is set).
    func surfaces(for scheme: ColorScheme, card: SurfacePalette.CardOption? = nil) -> SurfacePalette.Output {
        let window = windowBaseHex(for: scheme)
        let accent = ColorHex.normalized(accentHex)
            ?? ColorHex.hex(from: Color(nsColor: .controlAccentColor))
            ?? AppearanceDefaults.beluga
        return SurfacePalette.resolve(windowHex: window, scheme: scheme, accentHex: accent, card: card ?? cardOption)
    }

    /// Alpha for cards and panels in the main window. Settings is always opaque.
    var surfaceOpacity: Double {
        AppearanceResolver.surfaceOpacity(style: windowStyle)
    }

    var isWindowTransparent: Bool {
        AppearanceResolver.isWindowTransparent(style: windowStyle)
    }
}
