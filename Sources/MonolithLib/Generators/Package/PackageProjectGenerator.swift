import Foundation

enum PackageProjectGenerator {
    static func generate(config: PackageConfig, outputDir: String? = nil) throws {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)

        print("  Generating \(config.name)...")

        // Package.swift
        try FileWriter.writeFile(
            at: "Package.swift",
            content: PackageSwiftGenerator.generate(config: config),
            basePath: basePath
        )

        // Source files for each target
        for target in config.targets {
            try FileWriter.writeFile(
                at: "Sources/\(target.name)/\(target.name).swift",
                content: PackageSourceGenerator.generateSource(targetName: target.name),
                basePath: basePath
            )
        }

        // Test files for each target
        for target in config.targets {
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

        // Optional: Dev tooling
        if config.hasDevTooling {
            try FileWriter.writeToolingFiles(
                projectType: .package, appName: config.name,
                hasGitHooks: config.hasGitHooks,
                hasDefaultIsolation: config.hasDefaultIsolation,
                basePath: basePath
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
    }
}
