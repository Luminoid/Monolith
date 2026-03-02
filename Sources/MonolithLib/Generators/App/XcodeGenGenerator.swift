import Foundation

enum XcodeGenGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("name: \(config.name)")
        lines.append("")

        // Options
        lines.append("options:")
        lines.append("  bundleIdPrefix: \(bundlePrefix(config.bundleID))")
        lines.append("  deploymentTarget:")
        lines.append("    iOS: \(config.deploymentTarget)")
        if config.hasMacCatalyst {
            lines.append("    macCatalyst: \(config.deploymentTarget)")
        }
        lines.append("  xcodeVersion: \"16\"")
        lines.append("  generateEmptyDirectories: true")
        lines.append("")

        // Settings
        lines.append("settings:")
        lines.append("  base:")
        lines.append("    SWIFT_VERSION: \"6.0\"")
        lines.append("    DEVELOPMENT_TEAM: \"\"")
        lines.append("")

        // Targets
        lines.append("targets:")

        // App target
        lines.append("  \(config.name):")
        lines.append("    type: application")
        lines.append("    platform: iOS")
        if config.hasMacCatalyst {
            lines.append("    supportedDestinations: [iOS, macCatalyst]")
        }
        lines.append("    sources:")
        lines.append("      - \(config.name)")
        lines.append("    settings:")
        lines.append("      base:")
        lines.append("        PRODUCT_BUNDLE_IDENTIFIER: \(config.bundleID)")
        lines.append("        INFOPLIST_FILE: \(config.name)/Info.plist")
        lines.append("        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon")

        // Dependencies
        var deps: [String] = []
        if config.hasLumiKit { deps.append("LumiKit") }
        if config.hasSnapKit { deps.append("SnapKit") }
        if config.hasLottie { deps.append("Lottie") }

        if !deps.isEmpty {
            lines.append("    dependencies:")
            for dep in deps {
                lines.append("      - package: \(dep)")
            }
        }

        lines.append("")

        // Test target
        lines.append("  \(config.name)Tests:")
        lines.append("    type: bundle.unit-test")
        lines.append("    platform: iOS")
        lines.append("    sources:")
        lines.append("      - \(config.name)Tests")
        lines.append("    dependencies:")
        lines.append("      - target: \(config.name)")
        lines.append("")

        // Packages
        var packages: [[String: String]] = []
        if config.hasLumiKit {
            packages.append(["name": "LumiKit", "url": "https://github.com/Luminoid/LumiKit.git", "from": "0.2.0"])
        }
        if config.hasSnapKit {
            packages.append(["name": "SnapKit", "url": "https://github.com/SnapKit/SnapKit.git", "from": "5.7.0"])
        }
        if config.hasLottie {
            packages.append(["name": "Lottie", "url": "https://github.com/airbnb/lottie-spm.git", "from": "4.5.0"])
        }

        if !packages.isEmpty {
            lines.append("packages:")
            for pkg in packages {
                lines.append("  \(pkg["name"]!):")
                lines.append("    url: \(pkg["url"]!)")
                lines.append("    from: \(pkg["from"]!)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func bundlePrefix(_ bundleID: String) -> String {
        let parts = bundleID.split(separator: ".")
        if parts.count >= 2 {
            return parts.dropLast().joined(separator: ".")
        }
        return bundleID
    }
}
