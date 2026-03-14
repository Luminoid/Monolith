import Foundation

/// Derives a full 22-color LMKTheme palette from a single hex color.
enum ColorDeriver {
    // MARK: - Types

    struct RGB: Sendable, Equatable {
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

    struct HSB: Sendable {
        let hue: Double        // 0...360
        let saturation: Double // 0...1
        let brightness: Double // 0...1

        init(hue: Double, saturation: Double, brightness: Double) {
            self.hue = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
            self.saturation = min(1, max(0, saturation))
            self.brightness = min(1, max(0, brightness))
        }
    }

    struct ColorPair: Sendable {
        let light: RGB
        let dark: RGB
    }

    struct DerivedPalette: Sendable {
        let primary: ColorPair
        let primaryDark: ColorPair
        let secondary: ColorPair
        let tertiary: ColorPair
        let success: ColorPair
        let warning: ColorPair
        let error: ColorPair
        let info: ColorPair
        let textPrimary: TextColor
        let textSecondary: TextColor
        let textTertiary: TextColor
        let backgroundPrimary: ColorPair
        let backgroundSecondary: ColorPair
        let backgroundTertiary: ColorPair
        let divider: ColorPair
        let imageBorder: ImageBorderColor
        let graySoft: GrayColor
        let grayMuted: GrayColor
        let white: ColorPair
        let black: ColorPair
        let photoBrowserBackground: ColorPair
    }

    /// Text colors use system labels.
    enum TextColor: Sendable {
        case systemLabel
        case systemSecondaryLabel
        case systemTertiaryLabel

        var swiftCode: String {
            switch self {
            case .systemLabel: ".label"
            case .systemSecondaryLabel: ".secondaryLabel"
            case .systemTertiaryLabel: ".tertiaryLabel"
            }
        }
    }

    /// Image border derives from divider with alpha.
    struct ImageBorderColor: Sendable {
        let alpha: Double
    }

    /// Grayscale color (white: X).
    struct GrayColor: Sendable {
        let lightWhite: Double
        let darkWhite: Double
    }

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

    // MARK: - Palette Derivation

    /// Derive a full 22-color palette from a single hex color.
    static func derive(from hex: String) -> DerivedPalette? {
        guard let inputRGB = parseHex(hex) else { return nil }
        let inputHSB = rgbToHSB(inputRGB)

        // Primary
        let primaryLight = inputRGB
        let primaryDarkRGB = hsbToRGB(HSB(
            hue: inputHSB.hue,
            saturation: min(1, inputHSB.saturation + 0.05),
            brightness: max(0, inputHSB.brightness - 0.10)
        ))

        // Primary Dark (darker variant for accents)
        let primaryDarkLight = hsbToRGB(HSB(
            hue: inputHSB.hue,
            saturation: min(1, inputHSB.saturation + 0.10),
            brightness: max(0, inputHSB.brightness - 0.15)
        ))

        // Secondary (complementary-ish hue shift)
        let secHue = inputHSB.hue + 150
        let secondaryLight = hsbToRGB(HSB(
            hue: secHue,
            saturation: max(0, inputHSB.saturation - 0.20),
            brightness: max(0, inputHSB.brightness - 0.05)
        ))
        let secondaryDark = hsbToRGB(HSB(
            hue: secHue,
            saturation: max(0, inputHSB.saturation - 0.25),
            brightness: max(0, inputHSB.brightness - 0.10)
        ))

        // Tertiary (triadic hue shift)
        let terHue = inputHSB.hue + 210
        let tertiaryLight = hsbToRGB(HSB(
            hue: terHue,
            saturation: max(0, inputHSB.saturation - 0.15),
            brightness: max(0, inputHSB.brightness - 0.10)
        ))
        let tertiaryDark = hsbToRGB(HSB(
            hue: terHue,
            saturation: max(0, inputHSB.saturation - 0.10),
            brightness: min(1, inputHSB.brightness + 0.05)
        ))

        // Semantic (fixed)
        let success = ColorPair(
            light: RGB(52, 199, 89),
            dark: RGB(48, 209, 88)
        )
        let warning = ColorPair(
            light: RGB(214, 168, 92),
            dark: RGB(230, 184, 108)
        )
        let error = ColorPair(
            light: RGB(255, 59, 48),
            dark: RGB(255, 92, 82)
        )
        let info = ColorPair(
            light: RGB(111, 175, 207),
            dark: RGB(143, 207, 239)
        )

        // Backgrounds (hue-tinted)
        let bgLight1 = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.03, brightness: 0.97))
        let bgDark1 = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.06, brightness: 0.12))
        let bgLight2 = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.01, brightness: 0.98))
        let bgDark2 = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.05, brightness: 0.17))
        let bgLight3 = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.04, brightness: 0.95))
        let bgDark3 = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.05, brightness: 0.15))

        // Divider (hue-tinted)
        let dividerLight = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.03, brightness: 0.87))
        let dividerDark = hsbToRGB(HSB(hue: inputHSB.hue, saturation: 0.04, brightness: 0.24))

        return DerivedPalette(
            primary: ColorPair(light: primaryLight, dark: primaryDarkRGB),
            primaryDark: ColorPair(light: primaryDarkLight, dark: inputRGB),
            secondary: ColorPair(light: secondaryLight, dark: secondaryDark),
            tertiary: ColorPair(light: tertiaryLight, dark: tertiaryDark),
            success: success,
            warning: warning,
            error: error,
            info: info,
            textPrimary: .systemLabel,
            textSecondary: .systemSecondaryLabel,
            textTertiary: .systemTertiaryLabel,
            backgroundPrimary: ColorPair(light: bgLight1, dark: bgDark1),
            backgroundSecondary: ColorPair(light: bgLight2, dark: bgDark2),
            backgroundTertiary: ColorPair(light: bgLight3, dark: bgDark3),
            divider: ColorPair(light: dividerLight, dark: dividerDark),
            imageBorder: ImageBorderColor(alpha: 0.5),
            graySoft: GrayColor(lightWhite: 0.75, darkWhite: 0.45),
            grayMuted: GrayColor(lightWhite: 0.85, darkWhite: 0.35),
            white: ColorPair(light: RGB(250, 250, 250), dark: RGB(230, 230, 230)),
            black: ColorPair(light: RGB(26, 26, 26), dark: RGB(245, 245, 245)),
            photoBrowserBackground: ColorPair(light: RGB(26, 26, 26), dark: RGB(26, 26, 26))
        )
    }
}
