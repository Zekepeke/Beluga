import SwiftUI
import XCTest
@testable import OpenSuperWhisper

/// The default outputs are pinned to design/DESIGN.md. Custom colors go through the derivation rule.
final class SurfacePaletteTests: XCTestCase {

    private let beluga = "#2F7FB8"

    private func resolve(window: String, _ scheme: ColorScheme, accent: String = "#2F7FB8",
                         card: SurfacePalette.CardOption = .matchWindow) -> SurfacePalette.Output {
        SurfacePalette.resolve(windowHex: window, scheme: scheme, accentHex: accent, card: card)
    }

    private func maxChannelDistance(_ a: String, _ b: String) -> Int {
        let x = ColorHex.components(from: a)!, y = ColorHex.components(from: b)!
        return max(abs(Int(x.red) - Int(y.red)), abs(Int(x.green) - Int(y.green)), abs(Int(x.blue) - Int(y.blue)))
    }

    // MARK: - Defaults (DESIGN.md, exact)

    func testDefaultLight_matchesDesign() {
        let out = resolve(window: "#E6EFF6", .light)
        XCTAssertEqual(out.card, "#FFFFFF")
        XCTAssertEqual(out.panel, "#F2F6FA")
        XCTAssertEqual(out.border, "#D5E0EA")
        XCTAssertEqual(out.separator, "#D5E0EA")
        XCTAssertEqual(out.sidebar, "#DCE8F1")
        XCTAssertEqual(out.text, "#14202B")
        XCTAssertEqual(out.secondaryText, "#5B6B7A")
        XCTAssertEqual(out.accentText, "#2F7FB8")
    }

    func testDefaultDarkBlueGray_matchesDesign() {
        let out = resolve(window: "#161D23", .dark)
        XCTAssertEqual(out.card, "#1F2830")
        XCTAssertEqual(out.panel, "#27323B")
        XCTAssertEqual(out.border, "#2F3C47")
        XCTAssertEqual(out.separator, "#2F3C47")
        XCTAssertEqual(out.sidebar, "#11171B")
        XCTAssertEqual(out.text, "#E8EEF3")
        XCTAssertEqual(out.secondaryText, "#93A3B1")
        XCTAssertEqual(out.accentText, "#4A9AD4")
    }

    func testDefaultWindowColors_areTheStoreDefaults() {
        XCTAssertEqual(AppearanceDefaults.windowLightHex, "#E6EFF6")
        XCTAssertEqual(AppearanceDefaults.windowDarkHex, "#161D23")
    }

    func testDefaults_areCaseAndHashInsensitive() {
        XCTAssertEqual(resolve(window: "161d23", .dark, accent: "#2f7fb8"), resolve(window: "#161D23", .dark))
    }

    func testInvalidWindowHex_fallsBackToTheSchemeDefault() {
        XCTAssertEqual(resolve(window: "banana", .dark), resolve(window: "#161D23", .dark))
        XCTAssertEqual(resolve(window: "", .light), resolve(window: "#E6EFF6", .light))
    }

    func testDefaultContrast_meetsTheBoard() {
        let light = resolve(window: "#E6EFF6", .light)
        XCTAssertEqual(ColorHex.contrastRatio(light.text, light.card)!, 16.5, accuracy: 0.05)
        XCTAssertEqual(ColorHex.contrastRatio(light.secondaryText, light.card)!, 5.5, accuracy: 0.05)
        let dark = resolve(window: "#161D23", .dark)
        XCTAssertEqual(ColorHex.contrastRatio(dark.text, dark.card)!, 12.8, accuracy: 0.05)
        XCTAssertEqual(ColorHex.contrastRatio(dark.secondaryText, dark.card)!, 5.8, accuracy: 0.05)
        XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(dark.accentText, dark.card)!, 4.5)
    }

    // MARK: - The derivation rule

    func testRule_atTheDefaultWindowColor_stayCloseToTheDesignValues() {
        // A window color one step off the default is not pinned, so this exercises the rule itself.
        let dark = resolve(window: "#161D24", .dark)
        let pinnedDark = resolve(window: "#161D23", .dark)
        XCTAssertLessThanOrEqual(maxChannelDistance(dark.card, pinnedDark.card), 4)
        XCTAssertLessThanOrEqual(maxChannelDistance(dark.panel, pinnedDark.panel), 4)
        XCTAssertLessThanOrEqual(maxChannelDistance(dark.border, pinnedDark.border), 6)
        XCTAssertLessThanOrEqual(maxChannelDistance(dark.sidebar, pinnedDark.sidebar), 4)

        let light = resolve(window: "#E6EFF7", .light)
        let pinnedLight = resolve(window: "#E6EFF6", .light)
        XCTAssertEqual(light.card, "#FFFFFF")
        XCTAssertLessThanOrEqual(maxChannelDistance(light.panel, pinnedLight.panel), 4)
        XCTAssertLessThanOrEqual(maxChannelDistance(light.border, pinnedLight.border), 8)
        XCTAssertLessThanOrEqual(maxChannelDistance(light.sidebar, pinnedLight.sidebar), 8)
    }

    func testCustomDarkWindow_derivesSurfacesAboveIt() {
        let window = "#102A43"
        let out = resolve(window: window, .dark)
        let w = ColorHex.hsl(from: window)!
        let card = ColorHex.hsl(from: out.card)!
        let panel = ColorHex.hsl(from: out.panel)!
        let border = ColorHex.hsl(from: out.border)!
        let sidebar = ColorHex.hsl(from: out.sidebar)!
        XCTAssertGreaterThan(card.lightness, w.lightness)
        XCTAssertGreaterThan(panel.lightness, card.lightness)
        XCTAssertGreaterThan(border.lightness, panel.lightness)
        XCTAssertLessThan(sidebar.lightness, w.lightness)
        XCTAssertEqual(card.hue, w.hue, accuracy: 3)
        XCTAssertEqual(border.hue, w.hue, accuracy: 3)
        XCTAssertNotEqual(out.card, resolve(window: "#161D23", .dark).card)
        XCTAssertEqual(out.text, "#E8EEF3")
    }

    func testCustomLightWindow_derivesSurfacesFromIt() {
        let window = "#F0E6D8"
        let out = resolve(window: window, .light)
        let w = ColorHex.hsl(from: window)!
        XCTAssertEqual(out.card, "#FFFFFF")
        XCTAssertLessThan(ColorHex.hsl(from: out.border)!.lightness, w.lightness)
        XCTAssertLessThan(ColorHex.hsl(from: out.sidebar)!.lightness, w.lightness)
        XCTAssertGreaterThan(ColorHex.hsl(from: out.panel)!.lightness, w.lightness)
        XCTAssertEqual(ColorHex.hsl(from: out.border)!.hue, w.hue, accuracy: 3)
        XCTAssertNotEqual(out.panel, resolve(window: "#E6EFF6", .light).panel)
    }

    func testExtremeWindowColors_stayValidHex() {
        for window in ["#000000", "#FFFFFF", "#FF0000"] {
            for scheme in [ColorScheme.light, .dark] {
                let out = resolve(window: window, scheme)
                for hex in [out.card, out.panel, out.border, out.separator, out.sidebar, out.text, out.secondaryText, out.accentText, out.cardText, out.cardSecondaryText] {
                    XCTAssertNotNil(ColorHex.components(from: hex), "\(window) \(scheme) \(hex)")
                }
            }
        }
    }

    // MARK: - Card option

    func testCustomCard_overridesTheCardOnly() {
        let base = resolve(window: "#161D23", .dark)
        let custom = resolve(window: "#161D23", .dark, card: .custom(hex: "#2A343D"))
        XCTAssertEqual(custom.card, "#2A343D")
        XCTAssertEqual(custom.panel, base.panel)
        XCTAssertEqual(custom.border, base.border)
        XCTAssertEqual(custom.separator, base.separator)
        XCTAssertEqual(custom.sidebar, base.sidebar)
        XCTAssertEqual(custom.text, base.text)
        XCTAssertEqual(custom.secondaryText, base.secondaryText)
    }

    func testCustomCard_isNormalized() {
        XCTAssertEqual(resolve(window: "#E6EFF6", .light, card: .custom(hex: "eef3f8")).card, "#EEF3F8")
    }

    func testInvalidCustomCard_fallsBackToMatchWindow() {
        XCTAssertEqual(resolve(window: "#161D23", .dark, card: .custom(hex: "banana")), resolve(window: "#161D23", .dark))
    }

    func testLightCardInDarkMode_getsReadableTextAndTheAccentAsIs() {
        for paper in ["#FFFFFF", "#EEF3F8"] {
            let out = resolve(window: "#161D23", .dark, card: .custom(hex: paper))
            XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.cardText, out.card)!, 4.5, paper)
            XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.cardSecondaryText, out.card)!, 4.5, paper)
            // Text on the card follows the card, text on the window follows the scheme.
            XCTAssertEqual(out.cardAccentText, "#2F7FB8", paper)
            XCTAssertEqual(out.accentText, "#4A9AD4", paper)
        }
    }

    func testDarkCardInLightMode_getsReadableTextAndALiftedAccent() {
        for ink in ["#2A343D", "#10151A"] {
            let out = resolve(window: "#E6EFF6", .light, card: .custom(hex: ink))
            XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.cardText, out.card)!, 4.5, ink)
            XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.cardSecondaryText, out.card)!, 4.5, ink)
            XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.cardAccentText, out.card)!, 4.5, ink)
            // Text on the window itself is unaffected by the card.
            XCTAssertEqual(out.text, "#14202B")
            XCTAssertEqual(out.accentText, "#2F7FB8")
        }
    }

    func testDefaultCard_textOnCardIsTheSchemeText() {
        let light = resolve(window: "#E6EFF6", .light)
        XCTAssertEqual(light.cardText, light.text)
        XCTAssertEqual(light.cardSecondaryText, light.secondaryText)
        let dark = resolve(window: "#161D23", .dark)
        XCTAssertEqual(dark.cardText, dark.text)
        XCTAssertEqual(dark.cardAccentText, dark.accentText)
    }

    // MARK: - Accent text

    func testDarkAccentText_belugaBlue_isTheDesignedLift() {
        let out = resolve(window: "#161D23", .dark)
        XCTAssertEqual(out.accentText, "#4A9AD4")
        XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.accentText, out.card)!, 4.5)
    }

    func testDarkAccentText_customAccent_reachesFourPointFive() {
        for accent in ["#0A3D91", "#1E5AA0", "#7A1FA2", "#8B0000", "#2F7FB8", "#2f7fb9"] {
            let out = resolve(window: "#161D23", .dark, accent: accent)
            XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.accentText, out.card)!, 4.5, accent)
        }
    }

    func testDarkAccentText_keepsTheAccentHue() {
        let out = resolve(window: "#161D23", .dark, accent: "#1E5AA0")
        XCTAssertEqual(ColorHex.hsl(from: out.accentText)!.hue, ColorHex.hsl(from: "#1E5AA0")!.hue, accuracy: 2)
        XCTAssertGreaterThan(ColorHex.hsl(from: out.accentText)!.lightness, ColorHex.hsl(from: "#1E5AA0")!.lightness)
    }

    func testDarkAccentText_alreadyReadableAccent_isUnchanged() {
        XCTAssertEqual(resolve(window: "#161D23", .dark, accent: "#34C759").accentText, "#34C759")
    }

    func testDarkAccentText_neverLightensPastWhite() {
        let out = resolve(window: "#161D23", .dark, accent: "#000000")
        XCTAssertNotNil(ColorHex.components(from: out.accentText))
        XCTAssertGreaterThanOrEqual(ColorHex.contrastRatio(out.accentText, out.card)!, 4.5)
    }

    func testLightAccentText_isTheAccentAsIs() {
        for accent in ["#2F7FB8", "#34C759", "#AF52DE", "#FF2D92", "#1E5AA0"] {
            XCTAssertEqual(resolve(window: "#E6EFF6", .light, accent: accent).accentText, accent)
        }
    }

    func testAccentText_invalidAccent_fallsBackToBeluga() {
        XCTAssertEqual(resolve(window: "#E6EFF6", .light, accent: "").accentText, beluga)
        XCTAssertEqual(resolve(window: "#161D23", .dark, accent: "zzz").accentText, "#4A9AD4")
    }
}
