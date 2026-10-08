import Foundation

/// Derives an app's colors from a single hex color, each as a light/dark pair:
/// the three accents (`primary`, `secondary`, `tertiary`), `onAccent` (text and
/// icons drawn on a filled accent), three hue-tinted backgrounds, and a divider.
/// The source of the generated `LMKColorTheme` arguments and the standalone
/// `AppTheme`.
///
/// Every accent meets WCAG AA for text (4.5:1) in both appearances, against
/// `onAccent` and against each background, so it works as a button fill under
/// an `onAccent` title and as link or tint text on any of the backgrounds.
enum ColorDeriver {
    // MARK: - Types

    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double

        /// Integer components (0-255)
        var r255: Int { Int(round(red * 255)) }
        var g255: Int { Int(round(green * 255)) }
        var b255: Int { Int(round(blue * 255)) }

        init(red: Double, green: Double, blue: Double) {
            self.red = min(1, max(0, red))
            self.green = min(1, max(0, green))
            self.blue = min(1, max(0, blue))
        }

        init(_ r: Int, _ g: Int, _ b: Int) {
            self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
    }

    struct HSB {
        let hue: Double        // 0...360
        let saturation: Double // 0...1
        let brightness: Double // 0...1

        init(hue: Double, saturation: Double, brightness: Double) {
            self.hue = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
            self.saturation = min(1, max(0, saturation))
            self.brightness = min(1, max(0, brightness))
        }
    }

    struct ColorPair {
        let light: RGB
        let dark: RGB
    }

    /// Eight color pairs, every value already rounded to the 8-bit components the
    /// generated code emits, so a contrast measured here is the contrast that ships.
    struct DerivedPalette {
        let primary: ColorPair
        let secondary: ColorPair
        let tertiary: ColorPair
        /// Text and icons on a filled accent: near-white in light mode, a near-black
        /// tint of the input hue in dark mode (where the accents are light).
        let onAccent: ColorPair
        let backgroundPrimary: ColorPair
        let backgroundSecondary: ColorPair
        let backgroundTertiary: ColorPair
        let divider: ColorPair

        /// The pressed and selected shade of `primary` in each appearance (brightness
        /// times `pressedShadeFactor`). LumiKit derives the same shade itself, so only
        /// the standalone `AppTheme` emits it.
        var primaryVariant: ColorPair {
            ColorPair(light: ColorDeriver.pressedShade(of: primary.light), dark: ColorDeriver.pressedShade(of: primary.dark))
        }
    }

    // MARK: - Constants

    /// WCAG 2.x AA minimum contrast ratio for normal-size text.
    static let minimumTextContrast = 4.5

    /// LumiKit's brightness multiplier for an accent's pressed and selected shade
    /// (`primaryVariant`, a selected filled button).
    static let pressedShadeFactor = 0.85

    /// Step of the brightness and saturation searches that bring an accent up to
    /// `minimumTextContrast`.
    private static let contrastSearchStep = 0.02

    // MARK: - Hex Parsing

    /// Parse "#4CAF7D" → RGB. Returns nil on invalid input.
    static func parseHex(_ hex: String) -> RGB? {
        guard Validators.validateHexColor(hex) else { return nil }
        let digits = String(hex.dropFirst())

        let scanner = Scanner(string: digits)
        var hexValue: UInt64 = 0
        guard scanner.scanHexInt64(&hexValue) else { return nil }

        let r = Double((hexValue >> 16) & 0xFF) / 255
        let g = Double((hexValue >> 8) & 0xFF) / 255
        let b = Double(hexValue & 0xFF) / 255

        return RGB(red: r, green: g, blue: b)
    }

    // MARK: - Color Space Conversion

    static func rgbToHSB(_ rgb: RGB) -> HSB {
        let r = rgb.red, g = rgb.green, b = rgb.blue
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        let delta = maxVal - minVal

        let brightness = maxVal
        let saturation = maxVal == 0 ? 0 : delta / maxVal

        var hue: Double = 0
        if delta > 0 {
            if maxVal == r {
                hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxVal == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
        }

        if hue < 0 { hue += 360 }

        return HSB(hue: hue, saturation: saturation, brightness: brightness)
    }

    static func hsbToRGB(_ hsb: HSB) -> RGB {
        let h = hsb.hue, s = hsb.saturation, b = hsb.brightness

        if s == 0 {
            return RGB(red: b, green: b, blue: b)
        }

        let c = b * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c

        let (r1, g1, b1): (Double, Double, Double)
        switch h {
        case 0 ..< 60: (r1, g1, b1) = (c, x, 0)
        case 60 ..< 120: (r1, g1, b1) = (x, c, 0)
        case 120 ..< 180: (r1, g1, b1) = (0, c, x)
        case 180 ..< 240: (r1, g1, b1) = (0, x, c)
        case 240 ..< 300: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }

        return RGB(red: r1 + m, green: g1 + m, blue: b1 + m)
    }

    // MARK: - Contrast

    /// WCAG 2.x relative luminance of an sRGB color (0 for black, 1 for white).
    static func relativeLuminance(_ rgb: RGB) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.040_45 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    /// WCAG 2.x contrast ratio between two colors, from 1 (identical) to 21
    /// (black on white). Symmetric in its arguments.
    static func contrastRatio(_ first: RGB, _ second: RGB) -> Double {
        let lighter = max(relativeLuminance(first), relativeLuminance(second))
        let darker = min(relativeLuminance(first), relativeLuminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// The shade LumiKit draws an accent in when pressed or selected: the same hue
    /// and saturation at `pressedShadeFactor` times the brightness, rounded to 8 bits.
    static func pressedShade(of rgb: RGB) -> RGB {
        let hsb = rgbToHSB(rgb)
        return emitted(HSB(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness * pressedShadeFactor))
    }

    // MARK: - Palette Derivation

    /// Derive the palette from a single hex color.
    ///
    /// Pure black and pure white inputs would otherwise collapse the
    /// derivation math (every `max(0, b - X)` stays at 0 for black; every
    /// `min(1, b + X)` stays at 1 for white), producing an unusable
    /// single-tone palette. We clamp brightness into a safe inner band before
    /// derivation so the surrounding tones remain distinguishable. Adopters
    /// who genuinely want a black or white accent override the affected
    /// roles directly in the generated theme.
    ///
    /// Each accent then moves just far enough to meet `minimumTextContrast`:
    /// darker in light mode, lighter (and, if that is not enough, less
    /// saturated) in dark mode, where `onAccent` turns near-black. A dark-mode
    /// accent also keeps its pressed shade at that contrast against `onAccent`,
    /// since a selected filled button shows the shade under the same title.
    static func derive(from hex: String) -> DerivedPalette? {
        guard let inputRGB = parseHex(hex) else { return nil }
        let rawHSB = rgbToHSB(inputRGB)
        let inputHSB = HSB(
            hue: rawHSB.hue,
            saturation: rawHSB.saturation,
            brightness: min(0.85, max(0.20, rawHSB.brightness))
        )
        let hue = inputHSB.hue

        // Backgrounds and divider (hue-tinted)
        let backgroundPrimary = ColorPair(
            light: emitted(HSB(hue: hue, saturation: 0.03, brightness: 0.97)),
            dark: emitted(HSB(hue: hue, saturation: 0.06, brightness: 0.12))
        )
        let backgroundSecondary = ColorPair(
            light: emitted(HSB(hue: hue, saturation: 0.01, brightness: 0.98)),
            dark: emitted(HSB(hue: hue, saturation: 0.05, brightness: 0.17))
        )
        let backgroundTertiary = ColorPair(
            light: emitted(HSB(hue: hue, saturation: 0.04, brightness: 0.95)),
            dark: emitted(HSB(hue: hue, saturation: 0.05, brightness: 0.15))
        )
        let divider = ColorPair(
            light: emitted(HSB(hue: hue, saturation: 0.03, brightness: 0.87)),
            dark: emitted(HSB(hue: hue, saturation: 0.04, brightness: 0.24))
        )

        // On-accent: LumiKit's near-white default in light mode; in dark mode the
        // accents turn light, so the text on them turns dark (tinted to the hue).
        let onAccent = ColorPair(
            light: RGB(250, 250, 250),
            dark: emitted(HSB(hue: hue, saturation: 0.35, brightness: 0.12))
        )

        let backgrounds = [backgroundPrimary, backgroundSecondary, backgroundTertiary]
        let lightContrasts = [onAccent.light] + backgrounds.map(\.light)
        let darkContrasts = backgrounds.map(\.dark)

        // An accent pair from its light-mode starting point. The dark-mode search
        // starts from a softer, lighter version of it.
        func accent(from base: HSB) -> ColorPair {
            ColorPair(
                light: lightAccent(from: base, against: lightContrasts),
                dark: darkAccent(
                    from: HSB(hue: base.hue, saturation: base.saturation * 0.75, brightness: max(0.75, base.brightness)),
                    against: darkContrasts,
                    onAccent: onAccent.dark
                )
            )
        }

        // Secondary + Tertiary use an ANALOGOUS palette: small hue shifts
        // (+30°, -30°) that stay in-family with the primary. A triadic palette
        // (+150° secondary, +210° tertiary) produces jarring complementary
        // colors that fight the primary visually (e.g. a violet primary getting
        // an amber-gold secondary and a green tertiary). Analogous shifts read
        // as "lighter / darker / cooler / warmer variants of the primary",
        // which is what most apps want from a derived palette. Adopters who
        // want a complementary pairing override the affected arguments on the
        // generated theme directly.
        //
        // The secondary drops more saturation than the tertiary (−0.30 against
        // −0.20) and starts a little brighter, so it reads as a *muted* sibling
        // of the primary instead of a saturated peer.
        return DerivedPalette(
            primary: accent(from: inputHSB),
            secondary: accent(from: HSB(
                hue: hue + 30,
                saturation: inputHSB.saturation - 0.30,
                brightness: inputHSB.brightness + 0.05
            )),
            tertiary: accent(from: HSB(
                hue: hue - 30,
                saturation: inputHSB.saturation - 0.20,
                brightness: inputHSB.brightness - 0.05
            )),
            onAccent: onAccent,
            backgroundPrimary: backgroundPrimary,
            backgroundSecondary: backgroundSecondary,
            backgroundTertiary: backgroundTertiary,
            divider: divider
        )
    }

    // MARK: - Helpers

    /// `hsb` rounded to the 8-bit components the generated code writes out.
    private static func emitted(_ hsb: HSB) -> RGB {
        let rgb = hsbToRGB(hsb)
        return RGB(rgb.r255, rgb.g255, rgb.b255)
    }

    private static func meetsTextContrast(_ color: RGB, against others: [RGB]) -> Bool {
        others.allSatisfy { contrastRatio(color, $0) >= minimumTextContrast }
    }

    /// Lowers `start`'s brightness until the color meets `minimumTextContrast`
    /// against every color in `others` (light backgrounds and `onAccent`).
    /// Black always does, so the search ends.
    private static func lightAccent(from start: HSB, against others: [RGB]) -> RGB {
        var brightness = start.brightness
        var color = emitted(start)
        while brightness > 0, !meetsTextContrast(color, against: others) {
            brightness = max(0, brightness - contrastSearchStep)
            color = emitted(HSB(hue: start.hue, saturation: start.saturation, brightness: brightness))
        }
        return color
    }

    /// Raises `start`'s brightness, then lowers its saturation, until the color
    /// meets `minimumTextContrast` against every color in `others` (dark
    /// backgrounds) and its pressed shade still does against the near-black
    /// `onAccent`. White always does, so the search ends.
    private static func darkAccent(from start: HSB, against others: [RGB], onAccent: RGB) -> RGB {
        var hsb = start
        var color = emitted(hsb)
        while !(meetsTextContrast(color, against: others) && contrastRatio(pressedShade(of: color), onAccent) >= minimumTextContrast),
              hsb.brightness < 1 || hsb.saturation > 0 {
            hsb = hsb.brightness < 1
                ? HSB(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness + contrastSearchStep)
                : HSB(hue: hsb.hue, saturation: hsb.saturation - contrastSearchStep, brightness: 1)
            color = emitted(hsb)
        }
        return color
    }
}
