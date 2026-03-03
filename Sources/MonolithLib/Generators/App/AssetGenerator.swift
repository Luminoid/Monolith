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

    static func generateAppIconContents() -> String {
        """
        {
          "images" : [
            {
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
