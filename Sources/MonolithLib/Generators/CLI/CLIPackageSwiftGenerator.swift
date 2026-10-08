enum CLIPackageSwiftGenerator {
    /// The CLI's `Package.swift`: a `<libraryName>` library target holding the
    /// command, a `<name>` executable target whose `main.swift` calls it, and a
    /// `<libraryName>Tests` test target. See `CLIMainGenerator` for the layout.
    static func generate(config: CLIConfig) -> String {
        var lines: [String] = []

        lines.append("""
        // swift-tools-version: \(ToolVersion.swift)

        import PackageDescription

        let package = Package(
        """)
        lines.append("    name: \"\(config.name)\",")
        lines.append("    platforms: [")
        lines.append("        .macOS(.v14),")
        lines.append("    ],")
        lines.append("    products: [")
        lines.append("        .executable(name: \"\(config.name)\", targets: [\"\(config.name)\"]),")
        lines.append("    ],")

        // Dependencies. URL + version + SPM package name come from
        // KnownPackages.registry, the same source PackageSwiftGenerator and
        // XcodeGenGenerator read.
        let argParser = config.includeArgumentParser ? KnownPackages.registry["ArgumentParser"] : nil
        if let entry = argParser {
            lines.append("    dependencies: [")
            lines.append("        .package(url: \"\(entry.url)\", from: \"\(entry.defaultVersion)\"),")
            lines.append("    ],")
        }

        // .strictConcurrency is the Swift 6.2 language default at
        // swift-tools-version: 6.2; the .enableExperimentalFeature shim is
        // obsolete and emits a build warning. Intentionally omitted.

        lines.append("    targets: [")

        // Library target: the command itself.
        lines.append("        .target(")
        lines.append("            name: \"\(config.libraryName)\",")
        if let entry = argParser {
            lines.append("            dependencies: [")
            lines.append("                .product(name: \"\(entry.name)\", package: \"\(entry.resolvedPackageName)\"),")
            lines.append("            ]")
        } else {
            lines.append("            dependencies: []")
        }
        lines.append("        ),")

        // Executable target: `main.swift` calls into the library.
        lines.append("        .executableTarget(")
        lines.append("            name: \"\(config.name)\",")
        lines.append("            dependencies: [\"\(config.libraryName)\"]")
        lines.append("        ),")

        // Test target: imports the library, not the executable.
        lines.append("        .testTarget(")
        lines.append("            name: \"\(config.libraryName)Tests\",")
        lines.append("            dependencies: [\"\(config.libraryName)\"]")
        lines.append("        ),")

        lines.append("    ]")
        lines.append(")")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
