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

    static func hex(from color: Color) -> String? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func byte(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.redComponent), byte(rgb.greenComponent), byte(rgb.blueComponent))
    }
}
