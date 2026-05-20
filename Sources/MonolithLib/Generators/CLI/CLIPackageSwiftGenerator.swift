enum CLIPackageSwiftGenerator {
    static func generate(config: CLIConfig) -> String {
        var lines: [String] = []

        lines.append("""
        // swift-tools-version: 6.2

        import PackageDescription

        let package = Package(
        """)
        lines.append("    name: \"\(config.name)\",")
        lines.append("    platforms: [")
        lines.append("        .macOS(.v14),")
        lines.append("    ],")

        // Dependencies
        if config.includeArgumentParser {
            lines.append("    dependencies: [")
            lines.append("        .package(url: \"https://github.com/apple/swift-argument-parser.git\", from: \"\(DependencyVersion.argumentParser)\"),")
            lines.append("    ],")
        }

        // Targets
        lines.append("    targets: [")

        // Executable target
        var targetDeps: [String] = []
        if config.includeArgumentParser {
            targetDeps.append(".product(name: \"ArgumentParser\", package: \"swift-argument-parser\")")
        }

        // .strictConcurrency is the Swift 6.2 language default at
        // swift-tools-version: 6.2; the .enableExperimentalFeature shim is
        // obsolete and emits a build warning. Intentionally omitted.

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
