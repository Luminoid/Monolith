import Foundation

enum DesignSystemGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import UIKit")
        lines.append("")
        lines.append("/// App-specific design system extensions.")
        lines.append("/// Extends the base design system (LumiKit or standalone) with app-specific tokens.")
        lines.append("enum DesignSystem {")
        lines.append("")
        lines.append("    // MARK: - Cell")
        lines.append("")
        lines.append("    enum Cell {")
        lines.append("        static let defaultHeight: CGFloat = 60")
        lines.append("        static let compactHeight: CGFloat = 44")
        lines.append("    }")
        lines.append("")
        lines.append("    // MARK: - Layout")
        lines.append("")
        lines.append("    enum Layout {")
        lines.append("        static let cardCornerRadius: CGFloat = 12")
        lines.append("        static let buttonCornerRadius: CGFloat = 8")
        lines.append("        static let iconSize: CGFloat = 24")
        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
