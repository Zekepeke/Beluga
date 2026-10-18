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
        windowStyle = WindowBackgroundStyle(stored: defaults.string(forKey: Keys.windowBackgroundStyle) ?? "")
        windowColorHex = defaults.string(forKey: Keys.windowBackgroundHex) ?? ""
        tint = WindowTintModel(defaults: defaults)
    }

    func resetToDefaults() {
        accentHex = AppearanceDefaults.accentHex
        indicatorColorHex = AppearanceDefaults.indicatorColorHex
        indicatorSize = IndicatorSize.defaultValue
        indicatorBackground = IndicatorBackgroundStyle.defaultValue
        windowStyle = WindowBackgroundStyle.defaultValue
        windowColorHex = ""
        windowOpacity = AppearanceDefaults.windowOpacity
    }

    // MARK: - Resolved values

    /// nil means the system accent.
    var accentColor: Color? { AppearanceResolver.color(fromHex: accentHex) }

    /// nil means today's recording red.
    var indicatorDotColor: Color? { AppearanceResolver.color(fromHex: indicatorColorHex) }

    /// The window color for the scheme, or nil under the system style.
    func windowBaseColor(for scheme: ColorScheme) -> Color? {
        AppearanceResolver.windowBaseHex(style: windowStyle, customHex: windowColorHex, scheme: scheme)
            .flatMap { AppearanceResolver.color(fromHex: $0) }
    }

    /// Accent for explicit tints (e.g. toggle styles that name their color).
    var accent: Color { accentColor ?? .accentColor }

    /// The window fill: system paints the system color, solid its own color
    /// fully opaque, translucent its own color as a tint over the blur.
    func windowFill(for scheme: ColorScheme) -> (color: Color, opacity: Double) {
        let base = windowBaseColor(for: scheme) ?? ThemePalette.windowBackground(scheme)
        switch windowStyle {
        case .system, .solid: return (base, 1)
        case .translucent: return (base, windowOpacity)
        }
    }

    /// What the indicator's Solid style fills with: the window color at the moment.
    func indicatorSolidColor(for scheme: ColorScheme) -> Color {
        windowBaseColor(for: scheme) ?? ThemePalette.windowBackground(scheme)
    }

    var isWindowTransparent: Bool {
        AppearanceResolver.isWindowTransparent(style: windowStyle)
    }
}
