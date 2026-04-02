enum PackageSwiftGenerator {
    static func generate(config: PackageConfig) -> String {
        var lines: [String] = []

        lines.append("""
        // swift-tools-version: 6.2

        import PackageDescription

        let package = Package(
        """)
        lines.append("    name: \"\(config.name)\",")

        // Platforms
        if !config.platforms.isEmpty {
            lines.append("    platforms: [")
            for platform in config.platforms {
                lines.append("        \(platform.spmDeclaration),")
            }
            lines.append("    ],")
        }

        // Products
        lines.append("    products: [")
        for target in config.targets {
            lines.append("        .library(name: \"\(target.name)\", targets: [\"\(target.name)\"]),")
        }
        lines.append("    ],")

        // External dependencies
        let externalDeps = collectExternalDependencies(config: config)
        if !externalDeps.isEmpty {
            lines.append("    dependencies: [")
            for dep in externalDeps {
                lines.append("        \(dep),")
            }
            lines.append("    ],")
        }

        // Targets
        lines.append("    targets: [")

        for target in config.targets {
            let deps = resolveTargetDependencies(target: target, config: config)
            var swiftSettings: [String] = []

            if config.mainActorTargets.contains(target.name) {
                swiftSettings.append(".defaultIsolation(MainActor.self)")
            }
            if config.hasStrictConcurrency {
                swiftSettings.append(".enableExperimentalFeature(\"StrictConcurrency\")")
            }

            lines.append("        .target(")
            lines.append("            name: \"\(target.name)\",")

            if deps.isEmpty {
                lines.append("            dependencies: [],")
            } else {
                lines.append("            dependencies: [")
                for dep in deps {
                    lines.append("                \(dep),")
                }
                lines.append("            ],")
            }

            lines.append("            path: \"Sources/\(target.name)\"")

            if !swiftSettings.isEmpty {
                // Replace last line to add comma
                let lastIdx = lines.count - 1
                lines[lastIdx] += ","
                lines.append("            swiftSettings: [")
                for setting in swiftSettings {
                    lines.append("                \(setting),")
                }
                lines.append("            ]")
            }
            lines.append("        ),")
        }

        // Test targets
        for target in config.targets {
            lines.append("        .testTarget(")
            lines.append("            name: \"\(target.name)Tests\",")
            lines.append("            dependencies: [\"\(target.name)\"],")
            lines.append("            path: \"Tests/\(target.name)Tests\"")
            lines.append("        ),")
        }

        lines.append("    ]")
        lines.append(")")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Collect external package dependencies from all target dependency strings.
    private static func collectExternalDependencies(config: PackageConfig) -> [String] {
        var seen = Set<String>()
        var deps: [String] = []

        for target in config.targets {
            for dep in target.dependencies {
                // Internal target dependency if it matches another target name
                let isInternal = config.targets.contains { $0.name == dep }
                if !isInternal, !seen.contains(dep) {
                    seen.insert(dep)
                    if let packageDep = knownPackageDependency(dep) {
                        deps.append(packageDep)
                    }
                }
            }
        }

        return deps
    }

    /// Resolve a target's dependencies into SPM dependency format.
    private static func resolveTargetDependencies(target: TargetDefinition, config: PackageConfig) -> [String] {
        target.dependencies.map { dep in
            let isInternal = config.targets.contains { $0.name == dep }
            if isInternal {
                return "\"\(dep)\""
            } else if let product = knownProductDependency(dep) {
                return product
            } else {
                return "\"\(dep)\""
            }
        }
    }

    /// Map known dependency names to SPM .package declarations.
    private static func knownPackageDependency(_ name: String) -> String? {
        switch name {
        case "SnapKit":
            ".package(url: \"https://github.com/SnapKit/SnapKit.git\", from: \"\(DependencyVersion.snapKit)\")"
        case "Lottie":
            ".package(url: \"https://github.com/airbnb/lottie-spm.git\", from: \"\(DependencyVersion.lottie)\")"
        case "LookinServer":
            ".package(url: \"https://github.com/QMUI/LookinServer.git\", from: \"\(DependencyVersion.lookin)\")"
        default:
            nil
        }
    }

    /// Map known dependency names to .product target dependency declarations.
    private static func knownProductDependency(_ name: String) -> String? {
        switch name {
        case "SnapKit":
            ".product(name: \"SnapKit\", package: \"SnapKit\")"
        case "Lottie":
            ".product(name: \"Lottie\", package: \"lottie-spm\")"
        case "LookinServer":
            ".product(name: \"LookinServer\", package: \"LookinServer\", condition: .when(platforms: [.iOS]))"
        default:
            nil
        }
    }
}
