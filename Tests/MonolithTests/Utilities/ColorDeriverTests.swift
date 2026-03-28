import Foundation
import Testing
@testable import MonolithLib

struct ColorDeriverTests {
    // MARK: - Hex Parsing

    @Test
    func `parse valid hex color`() throws {
        let rgb = try #require(ColorDeriver.parseHex("#4CAF7D"))
        #expect(rgb.r255 == 76)
        #expect(rgb.g255 == 175)
        #expect(rgb.b255 == 125)
    }

    @Test
    func `parse lowercase hex`() throws {
        let rgb = try #require(ColorDeriver.parseHex("#4caf7d"))
        #expect(rgb.r255 == 76)
    }

    @Test
    func `parse black`() throws {
        let rgb = try #require(ColorDeriver.parseHex("#000000"))
        #expect(rgb.r255 == 0)
        #expect(rgb.g255 == 0)
        #expect(rgb.b255 == 0)
    }

    @Test
    func `parse white`() throws {
        let rgb = try #require(ColorDeriver.parseHex("#FFFFFF"))
        #expect(rgb.r255 == 255)
        #expect(rgb.g255 == 255)
        #expect(rgb.b255 == 255)
    }

    @Test
    func `reject invalid hex`() {
        #expect(ColorDeriver.parseHex("4CAF7D") == nil)
        #expect(ColorDeriver.parseHex("#GGG") == nil)
        #expect(ColorDeriver.parseHex("") == nil)
        #expect(ColorDeriver.parseHex("#4CA") == nil)
    }

    // MARK: - RGB ↔ HSB Conversion

    @Test
    func `RGB to HSB for pure red`() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 1, green: 0, blue: 0))
        #expect(abs(hsb.hue - 0) < 1)
        #expect(abs(hsb.saturation - 1) < 0.01)
        #expect(abs(hsb.brightness - 1) < 0.01)
    }

    @Test
    func `RGB to HSB for pure green`() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 0, green: 1, blue: 0))
        #expect(abs(hsb.hue - 120) < 1)
        #expect(abs(hsb.saturation - 1) < 0.01)
        #expect(abs(hsb.brightness - 1) < 0.01)
    }

    @Test
    func `RGB to HSB for pure blue`() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 0, green: 0, blue: 1))
        #expect(abs(hsb.hue - 240) < 1)
        #expect(abs(hsb.saturation - 1) < 0.01)
        #expect(abs(hsb.brightness - 1) < 0.01)
    }

    @Test
    func `RGB to HSB for gray (zero saturation)`() {
        let hsb = ColorDeriver.rgbToHSB(ColorDeriver.RGB(red: 0.5, green: 0.5, blue: 0.5))
        #expect(abs(hsb.saturation) < 0.01)
        #expect(abs(hsb.brightness - 0.5) < 0.01)
    }

    @Test
    func `RGB → HSB → RGB round-trip preserves values`() {
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

    @Test
    func `derive produces non-nil palette from valid hex`() {
        let palette = ColorDeriver.derive(from: "#4CAF7D")
        #expect(palette != nil)
    }

    @Test
    func `derive returns nil for invalid hex`() {
        #expect(ColorDeriver.derive(from: "invalid") == nil)
        #expect(ColorDeriver.derive(from: "") == nil)
    }

    @Test
    func `primary light matches input color`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        #expect(palette.primary.light.r255 == 76)
        #expect(palette.primary.light.g255 == 175)
        #expect(palette.primary.light.b255 == 125)
    }

    @Test
    func `primary dark is darker than primary light`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let lightBrightness = ColorDeriver.rgbToHSB(palette.primary.light).brightness
        let darkBrightness = ColorDeriver.rgbToHSB(palette.primary.dark).brightness
        #expect(darkBrightness < lightBrightness)
    }

    @Test
    func `semantic colors are fixed`() throws {
        let p1 = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let p2 = try #require(ColorDeriver.derive(from: "#D4875A"))

        // Warning should be same for both
        #expect(p1.warning.light.r255 == p2.warning.light.r255)
        #expect(p1.warning.light.g255 == p2.warning.light.g255)

        // Error should be same for both
        #expect(p1.error.light.r255 == p2.error.light.r255)

        // Info should be same for both
        #expect(p1.info.dark.r255 == p2.info.dark.r255)
    }

    @Test
    func `text colors use system labels`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        #expect(palette.textPrimary.swiftCode == ".label")
        #expect(palette.textSecondary.swiftCode == ".secondaryLabel")
        #expect(palette.textTertiary.swiftCode == ".tertiaryLabel")
    }

    @Test
    func `backgrounds are hue-tinted, not pure gray`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let bgHSB = ColorDeriver.rgbToHSB(palette.backgroundPrimary.light)
        // Should have some saturation (tinted), not zero
        #expect(bgHSB.saturation > 0.01)
        // Should be high brightness (near white for light mode)
        #expect(bgHSB.brightness > 0.9)
    }

    @Test
    func `backgrounds dark mode is low brightness`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let bgHSB = ColorDeriver.rgbToHSB(palette.backgroundPrimary.dark)
        #expect(bgHSB.brightness < 0.2)
    }

    @Test
    func `secondary hue is shifted from primary`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let primaryHSB = ColorDeriver.rgbToHSB(palette.primary.light)
        let secondaryHSB = ColorDeriver.rgbToHSB(palette.secondary.light)
        // Hue should differ significantly
        let hueDiff = abs(primaryHSB.hue - secondaryHSB.hue)
        #expect(hueDiff > 90)
    }

    @Test
    func `all ecosystem colors derive successfully`() {
        // All app theme colors from the plan
        let colors = ["#4CAF7D", "#D4875A", "#4A7FE0", "#5C6BC0", "#007AFF"]
        for hex in colors {
            let palette = ColorDeriver.derive(from: hex)
            #expect(palette != nil, "Failed to derive palette for \(hex)")
        }
    }

    @Test
    func `photo browser background is fixed dark`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        #expect(palette.photoBrowserBackground.light.r255 == 26)
        #expect(palette.photoBrowserBackground.dark.r255 == 26)
    }

    @Test
    func `white and black are constant`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        #expect(palette.white.light.r255 == 250)
        #expect(palette.black.light.r255 == 26)
        #expect(palette.black.dark.r255 == 245)
    }
}
