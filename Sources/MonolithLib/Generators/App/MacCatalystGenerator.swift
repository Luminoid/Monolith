import Foundation

enum MacCatalystGenerator {

    /// Generate Mac Catalyst window configuration extension.
    static func generateWindowConfig(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import UIKit")
        lines.append("")
        lines.append("// MARK: - Mac Catalyst Window Configuration")
        lines.append("")
        lines.append("#if targetEnvironment(macCatalyst)")
        lines.append("enum MacWindowConfig {")
        lines.append("")
        lines.append("    static func configure(_ windowScene: UIWindowScene) {")
        lines.append("        if let titlebar = windowScene.titlebar {")
        lines.append("            titlebar.titleVisibility = .hidden")
        lines.append("            titlebar.toolbar = nil")
        lines.append("        }")
        lines.append("        windowScene.sizeRestrictions?.minimumSize = CGSize(")
        lines.append("            width: AppConstants.MacWindow.minWidth,")
        lines.append("            height: AppConstants.MacWindow.minHeight")
        lines.append("        )")
        lines.append("        windowScene.sizeRestrictions?.maximumSize = CGSize(")
        lines.append("            width: AppConstants.MacWindow.maxWidth,")
        lines.append("            height: AppConstants.MacWindow.maxHeight")
        lines.append("        )")
        lines.append("    }")
        lines.append("}")
        lines.append("#endif")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Generate Mac Catalyst menu builder for AppDelegate.
    static func generateMenuBuilder(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import UIKit")
        lines.append("")
        lines.append("// MARK: - Mac Catalyst Menu")
        lines.append("")
        lines.append("#if targetEnvironment(macCatalyst)")
        lines.append("extension AppDelegate {")
        lines.append("")
        lines.append("    func buildAppMenu(with builder: any UIMenuBuilder) {")
        lines.append("        guard builder.system == .main else { return }")
        lines.append("")

        // Refresh
        lines.append("        let refreshCommand = UIKeyCommand(")
        lines.append("            title: \"Refresh\",")
        lines.append("            action: #selector(handleMacRefresh),")
        lines.append("            input: \"r\",")
        lines.append("            modifierFlags: .command")
        lines.append("        )")
        lines.append("")

        // Tab switching
        if config.hasTabs {
            for (index, tab) in config.tabs.enumerated() {
                let num = index + 1
                lines.append("        let \(tab.name.lowercased())TabCommand = UIKeyCommand(")
                lines.append("            title: \"\(tab.name)\",")
                lines.append("            action: #selector(handleMacSwitchTab),")
                lines.append("            input: \"\\(\"\\(\(num))\")\",")
                lines.append("            modifierFlags: .command")
                lines.append("        )")
                lines.append("")
            }
        }

        lines.append("        let appMenu = UIMenu(")
        lines.append("            title: \"\(config.name)\",")

        var children = ["refreshCommand"]
        if config.hasTabs {
            for tab in config.tabs {
                children.append("\(tab.name.lowercased())TabCommand")
            }
        }
        lines.append("            children: [\(children.joined(separator: ", "))]")
        lines.append("        )")
        lines.append("        builder.insertSibling(appMenu, afterMenu: .view)")
        lines.append("    }")
        lines.append("")

        lines.append("    @objc private func handleMacRefresh() {")
        lines.append("        NotificationCenter.default.post(name: AppNotification.macMenuRefresh, object: nil)")
        lines.append("    }")
        lines.append("")

        if config.hasTabs {
            lines.append("    @objc private func handleMacSwitchTab(_ sender: UIKeyCommand) {")
            lines.append("        guard let input = sender.input, let tag = Int(input) else { return }")
            lines.append("        NotificationCenter.default.post(")
            lines.append("            name: AppNotification.macMenuSwitchTab,")
            lines.append("            object: nil,")
            lines.append("            userInfo: [\"tab\": tag - 1]")
            lines.append("        )")
            lines.append("    }")
        }

        lines.append("}")
        lines.append("#endif")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
