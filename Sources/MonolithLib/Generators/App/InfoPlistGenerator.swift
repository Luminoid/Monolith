import Foundation

enum InfoPlistGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        lines.append("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">")
        lines.append("<plist version=\"1.0\">")
        lines.append("<dict>")

        // Scene Manifest
        lines.append("    <key>UIApplicationSceneManifest</key>")
        lines.append("    <dict>")
        lines.append("        <key>UIApplicationSupportsMultipleScenes</key>")
        lines.append("        <false/>")
        lines.append("        <key>UISceneConfigurations</key>")
        lines.append("        <dict>")
        lines.append("            <key>UIWindowSceneSessionRoleApplication</key>")
        lines.append("            <array>")
        lines.append("                <dict>")
        lines.append("                    <key>UISceneConfigurationName</key>")
        lines.append("                    <string>Default Configuration</string>")
        lines.append("                    <key>UISceneDelegateClassName</key>")
        lines.append("                    <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>")
        lines.append("                </dict>")
        lines.append("            </array>")
        lines.append("        </dict>")
        lines.append("    </dict>")

        lines.append("</dict>")
        lines.append("</plist>")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
