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

        // Build phase scripts (SwiftFormat before compile, SwiftLint after compile)
        if config.hasDevTooling {
            // Closing """ aligns to set 4-space YAML indent under target
            lines.append("""
            preBuildScripts:
              - name: SwiftFormat
                basedOnDependencyAnalysis: false
                script: |
                  if [[ "$(uname -m)" == arm64 ]]; then
                    export PATH="/opt/homebrew/bin:$PATH"
                  fi
                  if which swiftformat >/dev/null; then
                    swiftformat "${SRCROOT}"
                  else
                    echo "warning: SwiftFormat not installed"
                  fi
            postCompileScripts:
              - name: SwiftLint
                basedOnDependencyAnalysis: false
                script: |
                  if [[ "$(uname -m)" == arm64 ]]; then
                    export PATH="/opt/homebrew/bin:$PATH"
                  fi
                  if command -v swiftlint >/dev/null 2>&1; then
                    swiftlint
                  else
                    echo "warning: swiftlint command not found"
                  fi
            """)
        }

        // Dependencies
        struct TargetDep {
            let name: String
            let platforms: [String]?
        }

        var deps: [TargetDep] = []
        if config.hasLumiKit { deps.append(TargetDep(name: "LumiKit", platforms: nil)) }
        if config.hasSnapKit { deps.append(TargetDep(name: "SnapKit", platforms: nil)) }
        if config.hasLottie { deps.append(TargetDep(name: "Lottie", platforms: nil)) }
        if config.hasLookin { deps.append(TargetDep(name: "LookinServer", platforms: ["iOS"])) }

        if !deps.isEmpty {
            lines.append("    dependencies:")
            for dep in deps {
                if let platforms = dep.platforms {
                    lines.append("      - package: \(dep.name)")
                    lines.append("        platforms: [\(platforms.joined(separator: ", "))]")
                } else {
                    lines.append("      - package: \(dep.name)")
                }
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
