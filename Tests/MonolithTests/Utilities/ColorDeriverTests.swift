import Foundation
import Testing
@testable import MonolithLib

@Suite("ColorDeriver")
struct ColorDeriverTests {
    // MARK: - Hex Parsing

    @Test("parse valid hex color")
    func parseValidHex() {
        let rgb = ColorDeriver.parseHex("#4CAF7D")
        #expect(rgb != nil)
        #expect(rgb!.r255 == 76)
        #expect(rgb!.g255 == 175)
        #expect(rgb!.b255 == 125)
    }

    @Test("parse lowercase hex")
    func parseLowercaseHex() {
        let rgb = ColorDeriver.parseHex("#4caf7d")
        #expect(rgb != nil)
        #expect(rgb!.r255 == 76)
    }

    @Test("parse black")
    func parseBlack() {
        let rgb = ColorDeriver.parseHex("#000000")
        #expect(rgb != nil)
        #expect(rgb!.r255 == 0)
        #expect(rgb!.g255 == 0)
        #expect(rgb!.b255 == 0)
    }

    @Test("parse white")
    func parseWhite() {
        let rgb = ColorDeriver.parseHex("#FFFFFF")
        #expect(rgb != nil)
        #expect(rgb!.r255 == 255)
        #expect(rgb!.g255 == 255)
        #expect(rgb!.b255 == 255)
    }

    @Test("reject invalid hex")
    func rejectInvalid() {
        #expect(ColorDeriver.parseHex("4CAF7D") == nil)
        #expect(ColorDeriver.parseHex("#GGG") == nil)
        #expect(ColorDeriver.parseHex("") == nil)
        #expect(ColorDeriver.parseHex("#4CA") == nil)
    }

    // MARK: - RGB ↔ HSB Conversion

    @Test("RGB to HSB for pure red")
    func rgbToHSBRed() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 1, green: 0, blue: 0))
        #expect(abs(hsb.hue - 0) < 1)
        #expect(abs(hsb.saturation - 1) < 0.01)
        #expect(abs(hsb.brightness - 1) < 0.01)
    }

    @Test("RGB to HSB for pure green")
    func rgbToHSBGreen() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 0, green: 1, blue: 0))
        #expect(abs(hsb.hue - 120) < 1)
        #expect(abs(hsb.saturation - 1) < 0.01)
        #expect(abs(hsb.brightness - 1) < 0.01)
    }

    @Test("RGB to HSB for pure blue")
    func rgbToHSBBlue() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 0, green: 0, blue: 1))
        #expect(abs(hsb.hue - 240) < 1)
        #expect(abs(hsb.saturation - 1) < 0.01)
        #expect(abs(hsb.brightness - 1) < 0.01)
    }

    @Test("RGB to HSB for gray (zero saturation)")
    func rgbToHSBGray() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 0.5, green: 0.5, blue: 0.5))
        #expect(abs(hsb.saturation) < 0.01)
        #expect(abs(hsb.brightness - 0.5) < 0.01)
    }

    @Test("RGB → HSB → RGB round-trip preserves values")
    func roundTrip() {
        let colors: [ColorDeriver.RGB] = [
            ColorDeriver.RGB(76, 175, 125),  // Plantfolio green
            ColorDeriver.RGB(255, 0, 0),     // Red
            ColorDeriver.RGB(0, 0, 255),     // Blue
            ColorDeriver.RGB(128, 128, 128), // Gray
            ColorDeriver.RGB(212, 135, 90),  // PetPal brown
        ]

        for original in colors {
            let hsb = ColorDeriver.rgbToHSB(original)
            let recovered = ColorDeriver.hsbToRGB(hsb)
            #expect(abs(original.r255 - recovered.r255) <= 1, "Red mismatch for \(original)")
            #expect(abs(original.g255 - recovered.g255) <= 1, "Green mismatch for \(original)")
            #expect(abs(original.b255 - recovered.b255) <= 1, "Blue mismatch for \(original)")
        }
    }

    // MARK: - Palette Derivation

    @Test("derive produces non-nil palette from valid hex")
    func deriveProducesPalette() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")
        #expect(palette != nil)
    }

    @Test("derive returns nil for invalid hex")
    func deriveRejectsInvalid() {
        #expect(ColorDeriver.derive(from: "invalid") == nil)
        #expect(ColorDeriver.derive(from: "") == nil)
    }

    @Test("primary light matches input color")
    func primaryMatchesInput() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        #expect(palette.primary.light.r255 == 76)
        #expect(palette.primary.light.g255 == 175)
        #expect(palette.primary.light.b255 == 125)
    }

    @Test("primary dark is darker than primary light")
    func primaryDarkIsDarker() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        let lightBrightness = ColorDeriver.rgbToHSB(palette.primary.light).brightness
        let darkBrightness = ColorDeriver.rgbToHSB(palette.primary.dark).brightness
        #expect(darkBrightness < lightBrightness)
    }

    @Test("semantic colors are fixed")
    func semanticColorsFixed() {
        let p1 = ColorDeriver.derive(from: "#4CAF7D")!
        let p2 = ColorDeriver.derive(from: "#D4875A")!

        // Warning should be same for both
        #expect(p1.warning.light.r255 == p2.warning.light.r255)
        #expect(p1.warning.light.g255 == p2.warning.light.g255)

        // Error should be same for both
        #expect(p1.error.light.r255 == p2.error.light.r255)

        // Info should be same for both
        #expect(p1.info.dark.r255 == p2.info.dark.r255)
    }

    @Test("text colors use system labels")
    func textColorsUseSystemLabels() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        #expect(palette.textPrimary.swiftCode == ".label")
        #expect(palette.textSecondary.swiftCode == ".secondaryLabel")
        #expect(palette.textTertiary.swiftCode == ".tertiaryLabel")
    }

    @Test("backgrounds are hue-tinted, not pure gray")
    func backgroundsHueTinted() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        let bgHSB = ColorDeriver.rgbToHSB(palette.backgroundPrimary.light)
        // Should have some saturation (tinted), not zero
        #expect(bgHSB.saturation > 0.01)
        // Should be high brightness (near white for light mode)
        #expect(bgHSB.brightness > 0.9)
    }

    @Test("backgrounds dark mode is low brightness")
    func backgroundsDarkModeLow() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        let bgHSB = ColorDeriver.rgbToHSB(palette.backgroundPrimary.dark)
        #expect(bgHSB.brightness < 0.2)
    }

    @Test("secondary hue is shifted from primary")
    func secondaryHueShifted() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        let primaryHSB = ColorDeriver.rgbToHSB(palette.primary.light)
        let secondaryHSB = ColorDeriver.rgbToHSB(palette.secondary.light)
        // Hue should differ significantly
        let hueDiff = abs(primaryHSB.hue - secondaryHSB.hue)
        #expect(hueDiff > 90)
    }

    @Test("all ecosystem colors derive successfully")
    func allEcosystemColors() {
        // All app theme colors from the plan
        let colors = ["#4CAF7D", "#D4875A", "#4A7FE0", "#5C6BC0", "#007AFF"]
        for hex in colors {
            let palette = ColorDeriver.derive(from: hex)
            #expect(palette != nil, "Failed to derive palette for \(hex)")
        }
    }

    @Test("photo browser background is fixed dark")
    func photoBrowserFixed() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        #expect(palette.photoBrowserBackground.light.r255 == 26)
        #expect(palette.photoBrowserBackground.dark.r255 == 26)
    }

    @Test("white and black are constant")
    func whiteBlackConstant() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")!
        #expect(palette.white.light.r255 == 250)
        #expect(palette.black.light.r255 == 26)
        #expect(palette.black.dark.r255 == 245)
    }
}
