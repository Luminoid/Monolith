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

        // Products. Executable targets are not exported as `.library` products —
        // adopters invoke them via `swift run <name>`; declaring a library product
        // around them would cause `swift build` to also link them into every
        // downstream consumer.
        lines.append("    products: [")
        for target in config.targets where !target.isExecutable {
            lines.append("        .library(name: \"\(target.name)\", targets: [\"\(target.name)\"]),")
        }
        for target in config.targets where target.isExecutable {
            lines.append("        .executable(name: \"\(target.name)\", targets: [\"\(target.name)\"]),")
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

            lines.append("        .\(target.isExecutable ? "executableTarget" : "target")(")
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

            lines.append("            path: \"Sources/\(sourceDirectoryName(for: target))\"")

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

            // Test-helper targets emit no linkerSettings — Swift Testing is
            // bundled with the toolchain. Adopters who want XCTest interop
            // add `import XCTest` to the source themselves; `swift test`
            // links XCTest automatically when the import is present.
            lines.append("        ),")
        }

        // Test targets. Skip executable targets — sibling tool CLIs rarely have
        // unit tests of their own, and a `Tests/<name>Tests/` stub that imports
        // `@testable import <name>` against an `.executableTarget` would force
        // the executable to be re-emitted as a library on every test build.
        // Also skip `--test-helper-targets` libraries — those are test-helper
        // wrappers (a `*Testing` sibling that adopter test targets import);
        // they exist to be consumed, not tested in isolation.
        for target in config.targets where !shouldSkipTestTarget(target, config: config) {
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
            // Executable targets implicitly depend on ArgumentParser — `--targets
            // name:exec` is sugar for "scaffold a CLI sibling," so we surface the
            // package edge automatically. Adopters can still drop the dep by
            // editing Sources/<name>/<name>.swift + Package.swift post-gen.
            if target.isExecutable {
                allDepNames.append("ArgumentParser")
            }
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
    /// `packageDeps` (deduped) so cross-cutting deps appear once per target,
    /// and auto-adds ArgumentParser to executable targets.
    private static func resolveTargetDependencies(target: TargetDefinition, config: PackageConfig) -> [String] {
        var merged = target.dependencies
        if target.isExecutable, !merged.contains("ArgumentParser") {
            merged.append("ArgumentParser")
        }
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

    /// Targets that should NOT get an auto-generated `Tests/<name>Tests/` fixture.
    /// Executables don't take `@testable import` cleanly, and `--test-helper-targets`
    /// libraries are test-helpers consumed by adopters, not tested in isolation.
    /// Shared by `PackageSwiftGenerator`, `PackageProjectGenerator`, and
    /// `FileWriter.printDryRun` so all three views agree.
    static func shouldSkipTestTarget(_ target: TargetDefinition, config: PackageConfig) -> Bool {
        target.isExecutable || config.testHelperTargets.contains(target.name)
    }

    /// Source directory name for a target. Libraries use the target name as-is;
    /// executables UpperCamelCase the kebab-/snake-cased target name (matching
    /// swift-format / swift-protobuf convention — `Sources/SwiftFormat/` for the
    /// `swift-format` binary). The target name stays kebab-case so
    /// `swift run causeway-tools` works as users expect.
    static func sourceDirectoryName(for target: TargetDefinition) -> String {
        target.isExecutable ? target.name.upperCamelCased : target.name
    }

    /// Map a known dependency name to an SPM `.package(url:, from:)` declaration.
    /// Data comes from `KnownPackages.registry` — the single source of truth
    /// for URL, version, and SPM package name across every generator.
    private static func knownPackageDependency(_ name: String) -> String? {
        guard let entry = KnownPackages.entryOwning(product: name) else { return nil }
        return ".package(url: \"\(entry.url)\", from: \"\(entry.defaultVersion)\")"
    }

    /// Map a known dependency name to a `.product(name:, package:)`
    /// target-dependency declaration. Same registry lookup as
    /// `knownPackageDependency` so a single entry change propagates to both.
    private static func knownProductDependency(_ name: String) -> String? {
        guard let entry = KnownPackages.entryOwning(product: name) else { return nil }
        return ".product(name: \"\(name)\", package: \"\(entry.resolvedPackageName)\")"
    }
}
