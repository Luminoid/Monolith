import Foundation

enum ExportOptionsGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        lines.append("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">")
        lines.append("<plist version=\"1.0\">")
        lines.append("<dict>")
        lines.append("    <key>method</key>")
        lines.append("    <string>app-store-connect</string>")
        lines.append("    <key>destination</key>")
        lines.append("    <string>upload</string>")
        lines.append("    <key>signingStyle</key>")
        lines.append("    <string>automatic</string>")
        lines.append("    <key>uploadSymbols</key>")
        lines.append("    <true/>")
        lines.append("</dict>")
        lines.append("</plist>")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
