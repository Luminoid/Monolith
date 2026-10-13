enum MacCatalystGenerator {
    /// The smallest Mac window a generated app allows, in points. The one
    /// source for both `AppConstants.MacWindow` (written by
    /// `AppConstantsGenerator` into a new Mac Catalyst app) and the inline
    /// `minimumSize` below.
    static let minimumWindowWidth = 600
    static let minimumWindowHeight = 800

    /// The window setup a non-LumiKit Mac Catalyst app calls from its scene
    /// delegate: a hidden title bar and a minimum window size. There is no
    /// maximum, so the window can grow to fill the screen.
    ///
    /// The enum is `@MainActor` because `UIWindowScene` and its title bar are.
    ///
    /// - Parameter inlineConstants: `true` when the app has no
    ///   `AppConstants.MacWindow` to read (an existing app gaining Mac
    ///   Catalyst through `monolith add`): the enum then carries its own
    ///   minimum size, with the same values a new app gets.
    static func generateWindowConfig(inlineConstants: Bool = false) -> String {
        var lines = [
            "import UIKit",
            "",
            "// MARK: - Mac Catalyst Window Configuration",
            "",
            "#if targetEnvironment(macCatalyst)",
            "    @MainActor",
            "    enum MacWindowConfig {",
        ]
        if inlineConstants {
            lines += [
                "        /// The smallest window the layout supports.",
                "        static let minimumSize = CGSize(width: \(minimumWindowWidth), height: \(minimumWindowHeight))",
                "",
            ]
        }
        lines += [
            "        static func configure(_ windowScene: UIWindowScene) {",
            "            if let titlebar = windowScene.titlebar {",
            "                titlebar.titleVisibility = .hidden",
            "                titlebar.toolbar = nil",
            "            }",
        ]
        if inlineConstants {
            lines.append("            windowScene.sizeRestrictions?.minimumSize = minimumSize")
        } else {
            lines += [
                "            windowScene.sizeRestrictions?.minimumSize = CGSize(",
                "                width: AppConstants.MacWindow.minWidth,",
                "                height: AppConstants.MacWindow.minHeight",
                "            )",
            ]
        }
        lines += [
            "        }",
            "    }",
            "#endif",
            "",
        ]
        return lines.joined(separator: "\n")
    }
}
