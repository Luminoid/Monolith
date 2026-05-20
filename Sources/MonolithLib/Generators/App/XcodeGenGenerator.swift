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
        lines.append("  xcodeVersion: \"\(ToolVersion.xcode)\"")
        lines.append("  generateEmptyDirectories: true")
        lines.append("")

        // Settings
        lines.append("""
        settings:
          base:
            SWIFT_VERSION: "6.2"
            SWIFT_APPROACHABLE_CONCURRENCY: "YES"
            SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY: "YES"
            MARKETING_VERSION: "1.0.0"
            CURRENT_PROJECT_VERSION: "1"
            DEVELOPMENT_TEAM: ""
        """)
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
        lines.append("        GENERATE_INFOPLIST_FILE: YES")
        lines.append("        INFOPLIST_FILE: \(config.name)/Info.plist")
        lines.append("        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon")
        if config.hasWidget {
            // Required so Xcode resolves the App Group capability on the host
            // app — otherwise containerURL(forSecurityApplicationGroupIdentifier:)
            // returns nil at runtime.
            lines.append("        CODE_SIGN_ENTITLEMENTS: \(config.name)/\(config.name).entitlements")
        }

        // Build phase scripts (SwiftFormat before compile, SwiftLint after compile).
        // Emit each line explicitly so the YAML indentation lands under the
        // target (4 spaces). Multi-line heredocs strip-align to the closing
        // """, which would place these keys at column 0 — invalid YAML, and
        // xcodegen rejects the spec with a `parser: ... did not find expected
        // '-' indicator` error on the next target.
        if config.hasDevTooling {
            lines.append("    preBuildScripts:")
            lines.append("      - name: SwiftFormat")
            lines.append("        basedOnDependencyAnalysis: false")
            lines.append("        script: |")
            lines.append("          if [[ \"$(uname -m)\" == arm64 ]]; then")
            lines.append("            export PATH=\"/opt/homebrew/bin:$PATH\"")
            lines.append("          fi")
            lines.append("          if which swiftformat >/dev/null; then")
            lines.append("            swiftformat \"${SRCROOT}\"")
            lines.append("          else")
            lines.append("            echo \"warning: SwiftFormat not installed\"")
            lines.append("          fi")
            lines.append("    postCompileScripts:")
            lines.append("      - name: SwiftLint")
            lines.append("        basedOnDependencyAnalysis: false")
            lines.append("        script: |")
            lines.append("          if [[ \"$(uname -m)\" == arm64 ]]; then")
            lines.append("            export PATH=\"/opt/homebrew/bin:$PATH\"")
            lines.append("          fi")
            lines.append("          if command -v swiftlint >/dev/null 2>&1; then")
            lines.append("            swiftlint")
            lines.append("          else")
            lines.append("            echo \"warning: swiftlint command not found\"")
            lines.append("          fi")
        }

        // Dependencies
        struct TargetDep {
            /// The package name as declared under `packages:` in this YAML.
            let package: String
            /// The library product to link. When `nil`, xcodegen defaults to a
            /// product whose name matches `package`. Required when the package
            /// exposes multiple products (LumiKit → LumiKitUI / LumiKitCore /
            /// LumiKitLottie / LumiKitNetwork), otherwise xcodebuild fails
            /// with "Missing package product '<package>'".
            let product: String?
            let platforms: [String]?
        }

        var deps: [TargetDep] = []
        if config.hasLumiKit {
            // LumiKit exposes LumiKitCore / LumiKitUI / LumiKitLottie /
            // LumiKitNetwork as separate products. The generated theme file
            // imports LumiKitUI, which transitively re-exports LumiKitCore.
            deps.append(TargetDep(package: "LumiKit", product: "LumiKitUI", platforms: nil))
        }
        if config.hasSnapKit { deps.append(TargetDep(package: "SnapKit", product: nil, platforms: nil)) }
        if config.hasLottie { deps.append(TargetDep(package: "Lottie", product: nil, platforms: nil)) }
        if config.hasLookin { deps.append(TargetDep(package: "LookinServer", product: nil, platforms: ["iOS"])) }

        let widgetTargetName = "\(config.name)Widget"

        if !deps.isEmpty || config.hasWidget {
            lines.append("    dependencies:")
            for dep in deps {
                lines.append("      - package: \(dep.package)")
                if let product = dep.product {
                    lines.append("        product: \(product)")
                }
                if let platforms = dep.platforms {
                    lines.append("        platforms: [\(platforms.joined(separator: ", "))]")
                }
            }
            if config.hasWidget {
                lines.append("      - target: \(widgetTargetName)")
            }
        }

        lines.append("")

        // Widget extension target (must be declared before the test target so
        // the app's `- target: <name>Widget` dependency resolves cleanly).
        if config.hasWidget {
            lines.append("  \(widgetTargetName):")
            lines.append("    type: app-extension")
            lines.append("    platform: iOS")
            lines.append("    sources:")
            lines.append("      - \(widgetTargetName)")
            lines.append("    settings:")
            lines.append("      base:")
            lines.append("        PRODUCT_BUNDLE_IDENTIFIER: \(config.bundleID).Widget")
            lines.append("        INFOPLIST_FILE: \(widgetTargetName)/Info.plist")
            lines.append("        CODE_SIGN_ENTITLEMENTS: \(widgetTargetName)/\(widgetTargetName).entitlements")
            lines.append("        GENERATE_INFOPLIST_FILE: NO")
            lines.append("    dependencies:")
            lines.append("      - sdk: SwiftUI.framework")
            lines.append("      - sdk: WidgetKit.framework")
            lines.append("")
        }

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
        struct PackageDep {
            let name: String
            let url: String
            let from: String
        }

        var packages: [PackageDep] = []
        if config.hasLumiKit {
            packages.append(PackageDep(name: "LumiKit", url: "https://github.com/Luminoid/LumiKit.git", from: DependencyVersion.lumiKit))
        }
        if config.hasSnapKit {
            packages.append(PackageDep(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit.git", from: DependencyVersion.snapKit))
        }
        if config.hasLottie {
            packages.append(PackageDep(name: "Lottie", url: "https://github.com/airbnb/lottie-spm.git", from: DependencyVersion.lottie))
        }
        if config.hasLookin {
            packages.append(PackageDep(name: "LookinServer", url: "https://github.com/QMUI/LookinServer.git", from: DependencyVersion.lookin))
        }

        if !packages.isEmpty {
            lines.append("packages:")
            for pkg in packages {
                lines.append("  \(pkg.name):")
                lines.append("    url: \(pkg.url)")
                lines.append("    from: \(pkg.from)")
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
