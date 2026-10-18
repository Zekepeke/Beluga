import AppKit
import SwiftUI

enum ColorHex {
    static func components(from hex: String) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        var digits = Substring(hex)
        if digits.hasPrefix("#") { digits = digits.dropFirst() }
        guard digits.count == 6, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isHexDigit),
              let value = UInt32(digits, radix: 16)
        else { return nil }
        return (UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF))
    }

    static func normalized(_ hex: String) -> String? {
        guard let c = components(from: hex) else { return nil }
        return String(format: "#%02X%02X%02X", c.red, c.green, c.blue)
    }

    static func color(from hex: String) -> Color? {
        guard let c = components(from: hex) else { return nil }
        return Color(.sRGB, red: Double(c.red) / 255, green: Double(c.green) / 255, blue: Double(c.blue) / 255, opacity: 1)
    }

    static func nsColor(from hex: String) -> NSColor? {
        guard let c = components(from: hex) else { return nil }
        return NSColor(srgbRed: CGFloat(c.red) / 255, green: CGFloat(c.green) / 255, blue: CGFloat(c.blue) / 255, alpha: 1)
    }

    static func hex(from color: Color) -> String? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func byte(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.redComponent), byte(rgb.greenComponent), byte(rgb.blueComponent))
    }

    // MARK: - Color math (pure, hex in and out)

    /// Linear blend in sRGB: t = 0 is `a`, t = 1 is `b`. t is clamped.
    static func mix(_ a: String, _ b: String, _ t: Double) -> String? {
        guard let ca = components(from: a), let cb = components(from: b) else { return nil }
        let t = min(max(t.isNaN ? 0 : t, 0), 1)
        func blend(_ x: UInt8, _ y: UInt8) -> Int { Int((Double(x) + (Double(y) - Double(x)) * t).rounded()) }
        return String(format: "#%02X%02X%02X", blend(ca.red, cb.red), blend(ca.green, cb.green), blend(ca.blue, cb.blue))
    }

    /// Hue in degrees (0..<360), saturation and lightness in 0...1.
    static func hsl(from hex: String) -> (hue: Double, saturation: Double, lightness: Double)? {
        guard let c = components(from: hex) else { return nil }
        let r = Double(c.red) / 255, g = Double(c.green) / 255, b = Double(c.blue) / 255
        let high = max(r, g, b), low = min(r, g, b)
        let lightness = (high + low) / 2
        let delta = high - low
        guard delta > 0 else { return (0, 0, lightness) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        var hue: Double
        if high == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if high == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }
        return (hue, saturation, lightness)
    }

    /// Inputs are clamped: hue wraps, saturation and lightness stay in 0...1.
    static func hex(hue: Double, saturation: Double, lightness: Double) -> String {
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let s = min(max(saturation, 0), 1), l = min(max(lightness, 0), 1)
        let chroma = (1 - abs(2 * l - 1)) * s
        let x = chroma * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - chroma / 2
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<60: (r, g, b) = (chroma, x, 0)
        case ..<120: (r, g, b) = (x, chroma, 0)
        case ..<180: (r, g, b) = (0, chroma, x)
        case ..<240: (r, g, b) = (0, x, chroma)
        case ..<300: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        func byte(_ v: Double) -> Int { Int(((v + m) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    /// WCAG relative luminance, 0 (black) to 1 (white).
    static func relativeLuminance(_ hex: String) -> Double? {
        guard let c = components(from: hex) else { return nil }
        func linear(_ v: UInt8) -> Double {
            let x = Double(v) / 255
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    /// WCAG contrast ratio, 1...21.
    static func contrastRatio(_ a: String, _ b: String) -> Double? {
        guard let x = relativeLuminance(a), let y = relativeLuminance(b) else { return nil }
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
