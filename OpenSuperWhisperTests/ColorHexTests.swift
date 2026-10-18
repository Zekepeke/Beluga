import AppKit
import SwiftUI
import XCTest
@testable import OpenSuperWhisper

final class ColorHexTests: XCTestCase {

    func testComponents_withHash_parses() {
        let c = ColorHex.components(from: "#2F7FB8")
        XCTAssertEqual(c?.red, 0x2F)
        XCTAssertEqual(c?.green, 0x7F)
        XCTAssertEqual(c?.blue, 0xB8)
    }

    func testComponents_withoutHash_parses() {
        let c = ColorHex.components(from: "1B2A33")
        XCTAssertEqual(c?.red, 0x1B)
        XCTAssertEqual(c?.green, 0x2A)
        XCTAssertEqual(c?.blue, 0x33)
    }

    func testComponents_mixedCase_parses() {
        let upper = ColorHex.components(from: "#E6EFF6")
        let mixed = ColorHex.components(from: "#e6EfF6")
        XCTAssertNotNil(mixed)
        XCTAssertEqual(upper?.red, mixed?.red)
        XCTAssertEqual(upper?.green, mixed?.green)
        XCTAssertEqual(upper?.blue, mixed?.blue)
    }

    func testComponents_invalidInput_returnsNil() {
        for bad in ["", "#", "#FFF", "#FFFFF", "#FFFFFFF", "#GGGGGG", "12345Z", "##112233", " 112233", "#11 223", "#+12345"] {
            XCTAssertNil(ColorHex.components(from: bad), "expected nil for '\(bad)'")
            XCTAssertNil(ColorHex.color(from: bad), "expected nil color for '\(bad)'")
        }
    }

    func testHex_fromColor_isUppercaseWithHash() {
        let color = Color(.sRGB, red: 47.0 / 255, green: 127.0 / 255, blue: 184.0 / 255, opacity: 1)
        XCTAssertEqual(ColorHex.hex(from: color), "#2F7FB8")
    }

    func testRoundTrip_hexToColorToHex_isStable() throws {
        for hex in ["#000000", "#FFFFFF", "#2F7FB8", "#1B2A33", "#E6EFF6", "#FF2D92", "#010203"] {
            let color = try XCTUnwrap(ColorHex.color(from: hex))
            XCTAssertEqual(ColorHex.hex(from: color), hex)
        }
    }

    func testRoundTrip_withoutHash_normalizesToHash() throws {
        let color = try XCTUnwrap(ColorHex.color(from: "2f7fb8"))
        XCTAssertEqual(ColorHex.hex(from: color), "#2F7FB8")
    }
}
