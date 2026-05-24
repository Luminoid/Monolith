import Foundation

enum SPMAppGenerator {
    /// Generate the SPM `Package.swift`. `projectRoot` (when supplied) is
    /// used to normalize absolute external-package paths to project-root
    /// relative form — the same portability rationale as `XcodeGenGenerator`.
    static func generate(config: AppConfig, projectRoot: String? = nil) -> String {
        var lines: [String] = []

        lines.append("""
        // swift-tools-version: 6.2

        import PackageDescription

        """)
        lines.append("let package = Package(")
        lines.append("    name: \"\(config.name)\",")
        if config.hasLocalization {
            lines.append("    defaultLocalization: \"en\",")
        }

        // Platforms
        var platforms: [String] = []
        platforms.append(".iOS(.v\(majorVersion(config.deploymentTarget)))")
        if config.hasMacCatalyst {
            platforms.append(".macCatalyst(.v\(majorVersion(config.deploymentTarget)))")
        }
        lines.append("    platforms: [\(platforms.joined(separator: ", "))],")

        // Externals override built-ins (same rule as XcodeGenGenerator): when
        // the user passes `--external-packages LumiKit=...`, drop the default
        // URL entry so the user's pinned/local declaration wins.
        let externalPackageNames = Set(config.externalPackages.map(\.spmPackageName))

        // Dependencies
        var deps: [String] = []
        if config.hasLumiKit, !externalPackageNames.contains("LumiKit") {
            deps.append("        .package(url: \"https://github.com/Luminoid/LumiKit.git\", from: \"\(DependencyVersion.lumiKit)\"),")
        }
        if config.hasLottie, !externalPackageNames.contains("Lottie") {
            deps.append("        .package(url: \"https://github.com/airbnb/lottie-spm.git\", from: \"\(DependencyVersion.lottie)\"),")
        }
        // SnapKit + LookinServer: sourced from --use-packages or
        // --external-packages. The external-packages emit loop below handles
        // the .package(url:, from:) line for both.
        // External packages declared via --external-packages. Requirement is
        // verbatim SPM (e.g. `from: "0.3.0"` or `branch: "main"`), inserted
        // directly into the .package(url:...) call.
        // Path-form entries emit .package(name:, path:) instead — SPM uses the
        // explicit `name:` so .product(name:, package:) lookups still resolve.
        for ext in config.externalPackages {
            if ext.isLocalPath {
                // Normalize absolute paths to project-root-relative so
                // Package.swift is portable. See XcodeGenGenerator.normalizePath
                // for the rationale.
                let path = XcodeGenGenerator.normalizePath(ext.url, projectRoot: projectRoot)
                deps.append("        .package(name: \"\(ext.spmPackageName)\", path: \"\(path)\"),")
            } else {
                deps.append("        .package(url: \"\(ext.url)\", \(ext.requirement)),")
            }
        }

        if !deps.isEmpty {
            lines.append("    dependencies: [")
            for dep in deps {
                lines.append(dep)
            }
            lines.append("    ],")
        }

        // Targets
        lines.append("    targets: [")

        // Main executable target
        var targetDeps: [String] = []
        // Track product names we've already emitted so --target-deps doesn't
        // duplicate a built-in feature wiring (e.g. user passes
        // `--target-deps LumiKitUI` alongside `--features lumiKit`).
        var emittedProducts: Set<String> = []
        if config.hasLumiKit {
            targetDeps.append("            .product(name: \"LumiKitUI\", package: \"LumiKit\"),")
            emittedProducts.insert("LumiKitUI")
        }
        if config.hasLottie {
            targetDeps.append("            .product(name: \"Lottie\", package: \"lottie-spm\"),")
            emittedProducts.insert("Lottie")
        }
        // --target-deps: one .product(name:, package:) entry per requested
        // product. Routing lives on XcodeGenGenerator.routeProductToPackage
        // (direct match → prefix match → single-external fallback → product=package).
        // Platform conditionals come from KnownPackages.registry (LookinServer is iOS-only).
        for productName in config.targetDependencies where !emittedProducts.contains(productName) {
            let packageName = XcodeGenGenerator.routeProductToPackage(productName, externals: config.externalPackages)
            let platforms = KnownPackages.registry[productName]?.platforms
            // Registry stores platform names matching SPM enum cases (`iOS`,
            // `macOS`, etc.) so we just prefix with `.` to get `.iOS`.
            let conditionSuffix = if let platforms, !platforms.isEmpty {
                ", condition: .when(platforms: [\(platforms.map { ".\($0)" }.joined(separator: ", "))])"
            } else {
                ""
            }
            targetDeps.append("            .product(name: \"\(productName)\", package: \"\(packageName)\"\(conditionSuffix)),")
            emittedProducts.insert(productName)
        }

        lines.append("        .executableTarget(")
        lines.append("            name: \"\(config.name)\",")
        if !targetDeps.isEmpty {
            lines.append("            dependencies: [")
            for dep in targetDeps {
                lines.append(dep)
            }
            lines.append("            ],")
        }
        if config.hasLocalization {
            lines.append("            path: \"\(config.name)\",")
            lines.append("            resources: [.process(\"Resources\")]")
        } else {
            lines.append("            path: \"\(config.name)\"")
        }
        lines.append("        ),")

        // Test target
        lines.append("        .testTarget(")
        lines.append("            name: \"\(config.name)Tests\",")
        lines.append("            dependencies: [\"\(config.name)\"],")
        lines.append("            path: \"\(config.name)Tests\"")
        lines.append("        ),")

        lines.append("    ]")
        lines.append(")")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func majorVersion(_ version: String) -> String {
        String(version.split(separator: ".").first ?? "18")
    }
}
