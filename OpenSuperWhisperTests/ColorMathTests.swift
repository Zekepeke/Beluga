import XCTest
@testable import OpenSuperWhisper

final class ColorMathTests: XCTestCase {

    // MARK: - mix

    func testMix_endpointsReturnTheInputs() {
        XCTAssertEqual(ColorHex.mix("#102030", "#FFEEDD", 0), "#102030")
        XCTAssertEqual(ColorHex.mix("#102030", "#FFEEDD", 1), "#FFEEDD")
    }

    func testMix_halfway_blendsEachChannel() {
        XCTAssertEqual(ColorHex.mix("#000000", "#FFFFFF", 0.5), "#808080")
        XCTAssertEqual(ColorHex.mix("#E6EFF6", "#FFFFFF", 0.5), "#F3F7FB")
    }

    func testMix_clampsT() {
        XCTAssertEqual(ColorHex.mix("#102030", "#FFEEDD", -3), "#102030")
        XCTAssertEqual(ColorHex.mix("#102030", "#FFEEDD", 7), "#FFEEDD")
        XCTAssertEqual(ColorHex.mix("#102030", "#FFEEDD", .nan), "#102030")
    }

    func testMix_invalidHex_isNil() {
        XCTAssertNil(ColorHex.mix("banana", "#FFFFFF", 0.5))
        XCTAssertNil(ColorHex.mix("#FFFFFF", "", 0.5))
    }

    func testMix_acceptsMissingHashAndLowercase() {
        XCTAssertEqual(ColorHex.mix("ffffff", "#000000", 1), "#000000")
    }

    // MARK: - HSL

    func testHSL_roundTripsExactly() {
        for hex in ["#2F7FB8", "#161D23", "#E6EFF6", "#FFFFFF", "#000000", "#34C759", "#FF2D92", "#808080"] {
            let hsl = ColorHex.hsl(from: hex)!
            XCTAssertEqual(ColorHex.hex(hue: hsl.hue, saturation: hsl.saturation, lightness: hsl.lightness), hex, hex)
        }
    }

    func testHSL_knownValues() {
        let blue = ColorHex.hsl(from: "#2F7FB8")!
        XCTAssertEqual(blue.hue, 205, accuracy: 1.5)
        XCTAssertEqual(blue.lightness, 0.45, accuracy: 0.01)
        let gray = ColorHex.hsl(from: "#808080")!
        XCTAssertEqual(gray.saturation, 0, accuracy: 0.0001)
    }

    func testHSL_invalid_isNil() {
        XCTAssertNil(ColorHex.hsl(from: "nope"))
    }

    func testHexFromHSL_clampsLightness() {
        XCTAssertEqual(ColorHex.hex(hue: 200, saturation: 0.5, lightness: 2), "#FFFFFF")
        XCTAssertEqual(ColorHex.hex(hue: 200, saturation: 0.5, lightness: -1), "#000000")
    }

    // MARK: - Luminance and contrast

    func testContrast_blackOnWhite_is21() {
        XCTAssertEqual(ColorHex.contrastRatio("#000000", "#FFFFFF")!, 21, accuracy: 0.001)
        XCTAssertEqual(ColorHex.contrastRatio("#FFFFFF", "#FFFFFF")!, 1, accuracy: 0.001)
    }

    func testContrast_isSymmetric() {
        XCTAssertEqual(ColorHex.contrastRatio("#2F7FB8", "#1F2830")!, ColorHex.contrastRatio("#1F2830", "#2F7FB8")!, accuracy: 0.0001)
    }

    func testContrast_matchesTheBoardNumbers() {
        // design/DESIGN.md contrast notes.
        XCTAssertEqual(ColorHex.contrastRatio("#14202B", "#FFFFFF")!, 16.5, accuracy: 0.05)
        XCTAssertEqual(ColorHex.contrastRatio("#2F7FB8", "#FFFFFF")!, 4.3, accuracy: 0.05)
        XCTAssertEqual(ColorHex.contrastRatio("#E8EEF3", "#1F2830")!, 12.8, accuracy: 0.05)
        XCTAssertEqual(ColorHex.contrastRatio("#4A9AD4", "#1F2830")!, 4.9, accuracy: 0.05)
        XCTAssertEqual(ColorHex.contrastRatio("#2F7FB8", "#1F2830")!, 3.5, accuracy: 0.05)
    }
}
