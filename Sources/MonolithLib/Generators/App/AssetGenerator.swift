import Foundation

enum AssetGenerator {
    static func generateContentsJSON() -> String {
        """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    static func generateAccentColorContents(hex: String) -> String {
        guard let rgb = ColorDeriver.parseHex(hex) else {
            return generateAccentColorContents(r: 0, g: 122, b: 255)
        }
        return generateAccentColorContents(r: rgb.r255, g: rgb.g255, b: rgb.b255)
    }

    private static func generateAccentColorContents(r: Int, g: Int, b: Int) -> String {
        let rHex = String(format: "0x%02X", r)
        let gHex = String(format: "0x%02X", g)
        let bHex = String(format: "0x%02X", b)

        return """
        {
          "colors" : [
            {
              "color" : {
                "color-space" : "srgb",
                "components" : {
                  "alpha" : "1.000",
                  "blue" : "\(bHex)",
                  "green" : "\(gHex)",
                  "red" : "\(rHex)"
                }
              },
              "idiom" : "universal"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    /// AppIcon contents with three appearance variants (no-appearance / dark /
    /// tinted), matching iOS 18+'s alternate-icon-by-appearance model.
    /// `appearances`-keyed entries let Xcode generate the dark and tinted
    /// variants from the asset catalog at build time without per-app retrofitting.
    /// Adopters drop a 1024×1024 PNG into each slot; the no-appearance variant
    /// is the light-mode (and Mac Catalyst) icon, dark is iPhone/iPad dark mode,
    /// tinted is the iOS 18 monochrome variant for the "Tinted" home screen
    /// appearance setting.
    ///
    /// **Workspace lesson**: 1024×1024 icons must be RGB-opaque (no alpha
    /// channel) for the light variant — App Store Connect rejects on upload
    /// otherwise. Petfolio regressed on this twice. The generated
    /// `validate-app-icon.sh` script catches it before submission.
    static func generateAppIconContents() -> String {
        """
        {
          "images" : [
            {
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            },
            {
              "appearances" : [
                {
                  "appearance" : "luminosity",
                  "value" : "dark"
                }
              ],
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            },
            {
              "appearances" : [
                {
                  "appearance" : "luminosity",
                  "value" : "tinted"
                }
              ],
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }
}
