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
    case system, solid, translucent

    static let defaultValue: WindowBackgroundStyle = .translucent

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    init(stored: String) {
        self = WindowBackgroundStyle(rawValue: stored) ?? Self.defaultValue
    }
}

enum AppearanceDefaults {
    static let beluga = "#2F7FB8"
    static let accentHex = beluga
    static let indicatorColorHex = beluga
    static let windowDarkHex = "#1D2327"
    static let windowLightHex = "#E6EFF6"
    static let windowOpacity = 0.8
    static let opacityRange = 0.6...1.0
}

/// Pure resolution rules, kept separate from the store so they test without UserDefaults.
enum AppearanceResolver {
    static func color(fromHex hex: String) -> Color? {
        ColorHex.color(from: hex)
    }

    /// The window color (solid fill, or the tint over the blur), or nil for the system look.
    static func windowBaseHex(style: WindowBackgroundStyle, customHex: String, scheme: ColorScheme) -> String? {
        guard style != .system else { return nil }
        if let custom = ColorHex.normalized(customHex) { return custom }
        return scheme == .dark ? AppearanceDefaults.windowDarkHex : AppearanceDefaults.windowLightHex
    }

    static func clampedOpacity(_ value: Double) -> Double {
        guard !value.isNaN else { return AppearanceDefaults.windowOpacity }
        return min(max(value, AppearanceDefaults.opacityRange.lowerBound), AppearanceDefaults.opacityRange.upperBound)
    }

    static func isWindowTransparent(style: WindowBackgroundStyle) -> Bool {
        // Solid is always fully opaque; only translucent lets the desktop through.
        style == .translucent
    }
}
