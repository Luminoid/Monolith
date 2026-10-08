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
            ColorDeriver.RGB(76, 175, 125),  // Green
            ColorDeriver.RGB(255, 0, 0),     // Red
            ColorDeriver.RGB(0, 0, 255),     // Blue
            ColorDeriver.RGB(128, 128, 128), // Gray
            ColorDeriver.RGB(212, 135, 90),  // Brown
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
    func `primary light keeps an input that already meets AA`() throws {
        // #8E44AD reaches 4.5:1 against the near-white on-accent and every
        // light background as is, so the light primary is the input itself.
        let palette = try #require(ColorDeriver.derive(from: "#8E44AD"))
        #expect(palette.primary.light == ColorDeriver.RGB(0x8E, 0x44, 0xAD))
    }

    @Test
    func `primary light darkens an input below AA and keeps its hue`() throws {
        // #4CAF7D is 2.6:1 under a near-white title, so it darkens.
        let input = try #require(ColorDeriver.parseHex("#4CAF7D"))
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let inputHSB = ColorDeriver.rgbToHSB(input)
        let primaryHSB = ColorDeriver.rgbToHSB(palette.primary.light)
        #expect(primaryHSB.brightness < inputHSB.brightness)
        #expect(abs(primaryHSB.hue - inputHSB.hue) < 3)
        #expect(ColorDeriver.contrastRatio(palette.onAccent.light, palette.primary.light) >= ColorDeriver.minimumTextContrast)
    }

    @Test
    func `primary dark is lighter than primary light`() throws {
        // Dark mode accents sit on near-black backgrounds, so they get lighter,
        // never darker, than their light-mode counterparts.
        for hex in ["#4CAF7D", "#FF6B35", "#007AFF", "#8E44AD"] {
            let palette = try #require(ColorDeriver.derive(from: hex))
            let lightLuminance = ColorDeriver.relativeLuminance(palette.primary.light)
            let darkLuminance = ColorDeriver.relativeLuminance(palette.primary.dark)
            #expect(darkLuminance > lightLuminance, "dark primary not lighter for \(hex)")
        }
    }

    @Test
    func `on-accent is near-white in light mode and a near-black tint in dark mode`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#8E44AD"))
        #expect(palette.onAccent.light == ColorDeriver.RGB(250, 250, 250))
        let dark = ColorDeriver.rgbToHSB(palette.onAccent.dark)
        #expect(dark.brightness < 0.15)
        #expect(dark.saturation > 0.2, "dark on-accent should carry the input hue")
    }

    @Test
    func `primary variant is the pressed shade of primary`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let primary = ColorDeriver.rgbToHSB(palette.primary.dark)
        let variant = ColorDeriver.rgbToHSB(palette.primaryVariant.dark)
        #expect(abs(variant.brightness - primary.brightness * ColorDeriver.pressedShadeFactor) < 0.01)
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
    func `secondary hue is shifted analogously from primary`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let primaryHSB = ColorDeriver.rgbToHSB(palette.primary.light)
        let secondaryHSB = ColorDeriver.rgbToHSB(palette.secondary.light)
        // Analogous palette: secondary is shifted +30° from primary. Allow ±5°
        // for the rgb→hsb→shift→hsb→rgb→hsb round-trip's rounding wobble.
        let hueDiff = abs(primaryHSB.hue - secondaryHSB.hue)
        #expect(hueDiff >= 25 && hueDiff <= 35, "expected ~30° shift, got \(hueDiff)°")
    }

    @Test
    func `tertiary hue is shifted analogously the other direction`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let primaryHSB = ColorDeriver.rgbToHSB(palette.primary.light)
        let tertiaryHSB = ColorDeriver.rgbToHSB(palette.tertiary.light)
        // Tertiary is shifted -30° from primary. Hue wraps at 360, so account
        // for both the simple-subtraction case and the wrap case.
        let rawDiff = primaryHSB.hue - tertiaryHSB.hue
        let hueDiff = abs(rawDiff < -180 ? rawDiff + 360 : (rawDiff > 180 ? rawDiff - 360 : rawDiff))
        #expect(hueDiff >= 25 && hueDiff <= 35, "expected ~30° shift, got \(hueDiff)°")
    }

    @Test
    func `common primary colors derive successfully`() {
        let colors = ["#4CAF7D", "#D4875A", "#4A7FE0", "#5C6BC0", "#007AFF"]
        for hex in colors {
            let palette = ColorDeriver.derive(from: hex)
            #expect(palette != nil, "Failed to derive palette for \(hex)")
        }
    }

    // MARK: - Contrast

    @Test
    func `contrast ratio matches the WCAG reference values`() {
        let black = ColorDeriver.RGB(0, 0, 0)
        let white = ColorDeriver.RGB(255, 255, 255)
        #expect(abs(ColorDeriver.contrastRatio(black, white) - 21) < 0.001)
        #expect(abs(ColorDeriver.contrastRatio(white, white) - 1) < 0.001)
        // #777777 on white is the textbook just-below-AA gray (4.48:1).
        #expect(abs(ColorDeriver.contrastRatio(ColorDeriver.RGB(0x77, 0x77, 0x77), white) - 4.48) < 0.01)
        // Symmetric in its arguments.
        #expect(ColorDeriver.contrastRatio(black, white) == ColorDeriver.contrastRatio(white, black))
    }

    /// Every accent must work as a filled background under `onAccent` and as
    /// text or tint on every background, in both appearances. The sweep covers
    /// the hue circle at low, medium, and high saturation and brightness.
    @Test
    func `every derived accent meets WCAG AA in both modes`() throws {
        var checked = 0
        for hue in stride(from: 0.0, through: 330, by: 30) {
            for saturation in [0.3, 0.6, 0.9] {
                for brightness in [0.3, 0.6, 0.9] {
                    let rgb = ColorDeriver.hsbToRGB(ColorDeriver.HSB(hue: hue, saturation: saturation, brightness: brightness))
                    let hex = String(format: "#%02X%02X%02X", rgb.r255, rgb.g255, rgb.b255)
                    let palette = try #require(ColorDeriver.derive(from: hex))
                    let backgrounds = [palette.backgroundPrimary, palette.backgroundSecondary, palette.backgroundTertiary]
                    let accents = [("primary", palette.primary), ("secondary", palette.secondary), ("tertiary", palette.tertiary)]
                    for (role, accent) in accents {
                        expectAA(accent.light, palette.onAccent.light, "\(hex) light \(role) under onAccent")
                        expectAA(accent.dark, palette.onAccent.dark, "\(hex) dark \(role) under onAccent")
                        // A selected filled button shows the pressed shade under the same title.
                        expectAA(ColorDeriver.pressedShade(of: accent.dark), palette.onAccent.dark, "\(hex) dark pressed \(role) under onAccent")
                        for background in backgrounds {
                            expectAA(accent.light, background.light, "\(hex) light \(role) on background")
                            expectAA(accent.dark, background.dark, "\(hex) dark \(role) on background")
                        }
                    }
                    checked += 1
                }
            }
        }
        #expect(checked == 108)
    }

    @Test
    func `the failing inputs from the audit now meet AA`() throws {
        // Measured before the contrast floors: #4CAF7D 2.60 / 2.50 and #FF6B35
        // 3.67 / 3.45 (onAccent on primary / primary on background, light);
        // #007AFF 2.61 and #8E44AD 2.15 (dark primary on background).
        for hex in ["#4CAF7D", "#FF6B35", "#007AFF", "#8E44AD"] {
            let palette = try #require(ColorDeriver.derive(from: hex))
            expectAA(palette.onAccent.light, palette.primary.light, "\(hex) light onAccent on primary")
            expectAA(palette.primary.light, palette.backgroundPrimary.light, "\(hex) light primary on background")
            expectAA(palette.onAccent.dark, palette.primary.dark, "\(hex) dark onAccent on primary")
            expectAA(palette.primary.dark, palette.backgroundPrimary.dark, "\(hex) dark primary on background")
        }
    }

    // MARK: - Brightness-clamping edge cases

    /// Pure black would otherwise collapse every derived brightness to zero
    /// (multiplicative HSB math: `max(0, 0 - X) == 0`). The clamp lifts the
    /// effective input brightness so the primary stays visibly distinct from
    /// black.
    @Test
    func `derive against pure black produces a non-black primary`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#000000"))
        let primaryBrightness = ColorDeriver.rgbToHSB(palette.primary.light).brightness
        #expect(primaryBrightness > 0.1, "Primary should not collapse to black")
    }

    /// Pure white would saturate every brighten/lighten step at 1.0, producing
    /// a white-on-white palette. The clamp pulls the effective input back from
    /// the ceiling so derived tones can climb (and fall) around it.
    @Test
    func `derive against pure white produces non-white primaries`() throws {
        let palette = try #require(ColorDeriver.derive(from: "#FFFFFF"))
        #expect(ColorDeriver.rgbToHSB(palette.primary.light).brightness < 0.95, "Light primary should be visibly darker than pure white")
        #expect(ColorDeriver.rgbToHSB(palette.primary.dark).brightness < 0.95, "Dark primary should be visibly darker than pure white")
    }

    // MARK: - Helpers

    private func expectAA(
        _ first: ColorDeriver.RGB,
        _ second: ColorDeriver.RGB,
        _ context: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let ratio = ColorDeriver.contrastRatio(first, second)
        #expect(ratio >= ColorDeriver.minimumTextContrast, "\(context): \(ratio)", sourceLocation: sourceLocation)
    }
}
