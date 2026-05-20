import Foundation

enum PackageProjectGenerator {
    static func generate(config rawConfig: PackageConfig, outputDir: String? = nil) throws {
        // Merge platform floors from known external deps (LumiKit, SnapKit,
        // Lottie) before emitting anything. A package wiring LumiKit but
        // declaring only iOS will fail `swift build` on macOS hosts unless
        // its `platforms:` includes the LumiKit-required macOS 15+ floor.
        // Doing the merge here (not at CLI parse) ensures `--load-config` and
        // wizard paths get the same treatment.
        let config = rawConfig.mergingRequiredPlatforms()

        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)

        print("  Generating \(config.name)...")

        // Package.swift
        try FileWriter.writeFile(
            at: "Package.swift",
            content: PackageSwiftGenerator.generate(config: config),
            basePath: basePath
        )

        // Source files for each target. Library targets use `Sources/<Name>/<Name>.swift`;
        // executables use `Sources/<CamelCasedName>/<CamelCasedName>.swift` (matches
        // swift-format / swift-protobuf convention, where the binary is kebab-cased
        // but the source dir + entry-point type are UpperCamelCase). Test-helper
        // libraries (declared via `--test-helper-targets`) get a Swift Testing
        // stub so the workspace standard is the default and adopters see the
        // intended `import <Lib>Testing` pattern.
        let targetNames = Set(config.targets.map(\.name))
        for target in config.targets {
            let dirName = PackageSwiftGenerator.sourceDirectoryName(for: target)
            let sourceFileName = "\(dirName).swift"
            // External deps: every wired dep that isn't an internal target.
            // Used by the plain-source path to seed `import <Product>` lines so
            // a broken external dep fails at compile time, not silently as
            // dead weight in Package.swift.
            let externalDeps = target.dependencies.filter { !targetNames.contains($0) }
            let sourceContent: String = if target.isExecutable {
                PackageSourceGenerator.generateExecutable(
                    targetName: target.name,
                    internalLibDeps: target.dependencies.filter { targetNames.contains($0) }
                )
            } else if config.testHelperTargets.contains(target.name) {
                PackageSourceGenerator.generateTestHelper(
                    targetName: target.name,
                    internalLibDeps: target.dependencies.filter { targetNames.contains($0) }
                )
            } else {
                PackageSourceGenerator.generateSource(
                    targetName: target.name,
                    externalDeps: externalDeps
                )
            }
            try FileWriter.writeFile(
                at: "Sources/\(dirName)/\(sourceFileName)",
                content: sourceContent,
                basePath: basePath
            )

            // Materialize `.process(...)` resource directories declared via
            // --target-resources. Without this, `swift build` warns
            // `Invalid Resource '<dir>': File not found.` on every build
            // until the adopter manually creates the directory.
            for resourceDir in config.targetResources[target.name] ?? [] {
                try FileWriter.writeFile(
                    at: "Sources/\(dirName)/\(resourceDir)/.gitkeep",
                    content: "",
                    basePath: basePath
                )
            }
        }

        // Test files. Skip executables and test-helper libs — see
        // PackageSwiftGenerator.shouldSkipTestTarget for rationale.
        for target in config.targets where !PackageSwiftGenerator.shouldSkipTestTarget(target, config: config) {
            try FileWriter.writeFile(
                at: "Tests/\(target.name)Tests/\(target.name)Tests.swift",
                content: TestGenerator.generate(suiteName: target.name, targetName: target.name),
                basePath: basePath
            )
        }

        // .gitignore
        try FileWriter.writeFile(
            at: ".gitignore",
            content: GitignoreGenerator.generate(options: .init(projectType: .package)),
            basePath: basePath
        )

        // README
        try FileWriter.writeFile(
            at: "README.md",
            content: ReadmeGenerator.generateForPackage(config: config),
            basePath: basePath
        )

        // Optional: Dev tooling. The Makefile's xcodebuild SCHEME tracks the
        // resolved build scheme: `<Name>-Package` umbrella when targets are
        // mixed (executables + libs, or test-helpers alongside libs), else the
        // named `<Name>` scheme. The umbrella covers every target with one
        // xcodebuild invocation; the named scheme only covers the main lib.
        if config.hasDevTooling {
            try FileWriter.writeToolingFiles(
                projectType: .package, appName: config.name,
                hasGitHooks: config.hasGitHooks,
                hasDefaultIsolation: config.hasDefaultIsolation,
                basePath: basePath,
                xcodeBuildScheme: config.xcodeBuildScheme
            )
        }

        // Optional: Git hooks
        if config.hasGitHooks {
            try FileWriter.writeGitHooks(basePath: basePath)
        }

        // Optional: CLAUDE.md, LICENSE, CHANGELOG
        try FileWriter.writeOptionalFiles(
            claudeMDContent: config.features.contains(.claudeMD)
                ? ClaudeMDGenerator.generateForPackage(config: config) : nil,
            licenseAuthor: config.features.contains(.licenseChangelog)
                ? config.author : nil,
            licenseType: config.licenseType,
            basePath: basePath
        )

        print()
        print("  Done!")
        if config.hasDevTooling || config.hasGitHooks {
            print()
            print("  Next steps:")
            if config.hasDevTooling {
                print("    brew bundle")
            }
            if config.hasGitHooks {
                print("    make setup-hooks")
            }
        }
    }
}
