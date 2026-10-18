import SwiftUI

enum IndicatorSize: String, CaseIterable, Identifiable {
    case small, medium, large

    static let defaultValue: IndicatorSize = .medium

    var id: String { rawValue }

    var scale: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.25
        }
    }

    var label: String { rawValue.capitalized }

    init(stored: String) {
        self = IndicatorSize(rawValue: stored) ?? Self.defaultValue
    }
}

enum IndicatorBackgroundStyle: String, CaseIterable, Identifiable {
    case standard = "default"
    case solid
    case translucent

    static let defaultValue: IndicatorBackgroundStyle = .standard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Default"
        case .solid: return "Solid"
        case .translucent: return "Translucent"
        }
    }

    init(stored: String) {
        self = IndicatorBackgroundStyle(rawValue: stored) ?? Self.defaultValue
    }
}

enum WindowBackgroundStyle: String, CaseIterable, Identifiable {
    case solid, translucent

    static let defaultValue: WindowBackgroundStyle = .translucent

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    /// Older versions also stored "system" (macOS's plain window color). That option is gone,
    /// so it, like any unknown value, reads as the default.
    init(stored: String) {
        self = WindowBackgroundStyle(rawValue: stored) ?? Self.defaultValue
    }

    /// True for a stored value from a removed option, which also resets the tint strength.
    static func isRetired(stored: String) -> Bool {
        stored == "system"
    }
}

enum AppearanceDefaults {
    static let beluga = "#2F7FB8"
    static let accentHex = beluga
    static let indicatorColorHex = beluga
    static let windowDarkHex = "#161D23"
    static let windowLightHex = "#E6EFF6"
    static let windowOpacity = 0.8
    static let opacityRange = 0.6...1.0
    /// Empty means the card color follows the window color.
    static let cardColorHex = ""
    /// Cards and panels sit slightly see-through on a translucent window so text stays readable.
    static let translucentSurfaceOpacity = 0.92

    struct CardPreset: Equatable {
        let name: String
        let hex: String
    }

    static let cardPresets = [
        CardPreset(name: "Paper", hex: "#FFFFFF"),
        CardPreset(name: "Mist", hex: "#EEF3F8"),
        CardPreset(name: "Slate", hex: "#2A343D"),
        CardPreset(name: "Ink", hex: "#10151A"),
    ]
}

/// Pure resolution rules, kept separate from the store so they test without UserDefaults.
enum AppearanceResolver {
    static func color(fromHex hex: String) -> Color? {
        ColorHex.color(from: hex)
    }

    /// The window color (solid fill, or the tint over the blur): the custom color if valid,
    /// otherwise the Beluga default for the scheme. Light and dark follow macOS through `scheme`.
    static func windowBaseHex(customHex: String, scheme: ColorScheme) -> String {
        if let custom = ColorHex.normalized(customHex) { return custom }
        return scheme == .dark ? AppearanceDefaults.windowDarkHex : AppearanceDefaults.windowLightHex
    }

    static func clampedOpacity(_ value: Double) -> Double {
        guard !value.isNaN else { return AppearanceDefaults.windowOpacity }
        return min(max(value, AppearanceDefaults.opacityRange.lowerBound), AppearanceDefaults.opacityRange.upperBound)
    }

    /// Alpha for card and panel surfaces: only a translucent window lets them show through.
    static func surfaceOpacity(style: WindowBackgroundStyle) -> Double {
        style == .translucent ? AppearanceDefaults.translucentSurfaceOpacity : 1
    }

    static func isWindowTransparent(style: WindowBackgroundStyle) -> Bool {
        // Solid is always fully opaque; only translucent lets the desktop through.
        style == .translucent
    }
}
