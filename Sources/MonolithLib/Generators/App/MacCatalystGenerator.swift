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

}
