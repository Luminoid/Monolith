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

        // Dependencies. URL + version + SPM package name come from
        // KnownPackages.registry — the same source PackageSwiftGenerator,
        // SPMAppGenerator, and XcodeGenGenerator read.
        let argParser = KnownPackages.registry["ArgumentParser"]
        if config.includeArgumentParser, let entry = argParser {
            lines.append("    dependencies: [")
            lines.append("        .package(url: \"\(entry.url)\", from: \"\(entry.defaultVersion)\"),")
            lines.append("    ],")
        }

        // Targets
        lines.append("    targets: [")

        // Executable target
        var targetDeps: [String] = []
        if config.includeArgumentParser, let entry = argParser {
            targetDeps.append(".product(name: \"\(entry.name)\", package: \"\(entry.resolvedPackageName)\")")
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
