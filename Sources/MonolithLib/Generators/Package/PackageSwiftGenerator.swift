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
            // .strictConcurrency is the Swift 6.2 language default at
            // swift-tools-version: 6.2; the .enableExperimentalFeature shim
            // is obsolete and emits a build warning. Intentionally omitted.

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

            // Resources
            if let resourceDirs = config.targetResources[target.name], !resourceDirs.isEmpty {
                let lastIdx = lines.count - 1
                lines[lastIdx] += ","
                lines.append("            resources: [")
                for dir in resourceDirs {
                    lines.append("                .process(\"\(dir)\"),")
                }
                lines.append("            ]")
            }

            if !swiftSettings.isEmpty {
                let lastIdx = lines.count - 1
                lines[lastIdx] += ","
                lines.append("            swiftSettings: [")
                for setting in swiftSettings {
                    lines.append("                \(setting),")
                }
                lines.append("            ]")
            }

            // XCTest linker — for test-utility libraries imported by adopter test targets
            if config.xctestTargets.contains(target.name) {
                let lastIdx = lines.count - 1
                lines[lastIdx] += ","
                lines.append("            linkerSettings: [")
                lines.append("                .linkedFramework(\"XCTest\"),")
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

    /// Collect external package dependencies from all target dependency strings
    /// plus the cross-cutting `packageDeps`. User-declared `externalPackages`
    /// take precedence over the hardcoded registry.
    ///
    /// Dedupes by the emitted `.package(url:...)` string rather than dep name, so multiple
    /// product names backed by the same SPM package (e.g. `LumiKitCore` + `LumiKitUI`) only
    /// produce one entry in the package's `dependencies:` array.
    private static func collectExternalDependencies(config: PackageConfig) -> [String] {
        var seen = Set<String>()
        var deps: [String] = []

        let externalPackageMap = Dictionary(uniqueKeysWithValues: config.externalPackages.map { ($0.name, $0) })

        var allDepNames: [String] = []
        for target in config.targets {
            allDepNames.append(contentsOf: target.dependencies)
        }
        allDepNames.append(contentsOf: config.packageDeps)

        for dep in allDepNames {
            let isInternal = config.targets.contains { $0.name == dep }
            guard !isInternal else { continue }
            let packageDecl: String? = if let ext = externalPackageMap[dep] {
                ".package(url: \"\(ext.url)\", \(ext.requirement))"
            } else {
                knownPackageDependency(dep)
            }
            guard let packageDecl else { continue }
            if seen.insert(packageDecl).inserted {
                deps.append(packageDecl)
            }
        }

        return deps
    }

    /// Resolve a target's dependencies into SPM dependency format. Merges in
    /// `packageDeps` (deduped) so cross-cutting deps appear once per target.
    private static func resolveTargetDependencies(target: TargetDefinition, config: PackageConfig) -> [String] {
        var merged = target.dependencies
        for dep in config.packageDeps where !merged.contains(dep) {
            merged.append(dep)
        }

        let externalPackageMap = Dictionary(uniqueKeysWithValues: config.externalPackages.map { ($0.name, $0) })

        return merged.map { dep in
            let isInternal = config.targets.contains { $0.name == dep }
            if isInternal {
                return "\"\(dep)\""
            } else if let ext = externalPackageMap[dep] {
                return ".product(name: \"\(ext.name)\", package: \"\(ext.spmPackageName)\")"
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
        case "LumiKitCore", "LumiKitUI", "LumiKitLottie", "LumiKitNetwork":
            ".package(url: \"https://github.com/Luminoid/LumiKit.git\", from: \"\(DependencyVersion.lumiKit)\")"
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
        case "LumiKitCore", "LumiKitUI", "LumiKitLottie", "LumiKitNetwork":
            ".product(name: \"\(name)\", package: \"LumiKit\")"
        default:
            nil
        }
    }
}
