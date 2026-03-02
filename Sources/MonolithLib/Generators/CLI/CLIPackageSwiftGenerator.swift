enum CLIPackageSwiftGenerator {

    static func generate(config: CLIConfig) -> String {
        var lines: [String] = []

        lines.append("// swift-tools-version: 6.2")
        lines.append("")
        lines.append("import PackageDescription")
        lines.append("")
        lines.append("let package = Package(")
        lines.append("    name: \"\(config.name)\",")
        lines.append("    platforms: [")
        lines.append("        .macOS(.v14),")
        lines.append("    ],")

        // Dependencies
        if config.includeArgumentParser {
            lines.append("    dependencies: [")
            lines.append("        .package(url: \"https://github.com/apple/swift-argument-parser.git\", from: \"1.7.0\"),")
            lines.append("    ],")
        }

        // Targets
        lines.append("    targets: [")

        // Executable target
        var targetDeps: [String] = []
        if config.includeArgumentParser {
            targetDeps.append(".product(name: \"ArgumentParser\", package: \"swift-argument-parser\")")
        }

        var swiftSettings: [String] = []
        if config.hasStrictConcurrency {
            swiftSettings.append(".enableExperimentalFeature(\"StrictConcurrency\")")
        }

        lines.append("        .executableTarget(")
        lines.append("            name: \"\(config.name)\",")
        if targetDeps.isEmpty {
            lines.append("            dependencies: []")
        } else {
            lines.append("            dependencies: [")
            for dep in targetDeps {
                lines.append("                \(dep),")
            }
            lines.append("            ]")
        }
        if !swiftSettings.isEmpty {
            // Remove last line's closing and add comma
            let lastIdx = lines.count - 1
            lines[lastIdx] = lines[lastIdx] + ","
            lines.append("            swiftSettings: [")
            for setting in swiftSettings {
                lines.append("                \(setting),")
            }
            lines.append("            ]")
        }
        lines.append("        ),")

        // Test target
        lines.append("        .testTarget(")
        lines.append("            name: \"\(config.name)Tests\",")
        lines.append("            dependencies: [\"\(config.name)\"]")
        lines.append("        ),")

        lines.append("    ]")
        lines.append(")")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
