import Foundation

enum CLIProjectGenerator {
    static func generate(config: CLIConfig, outputDir: String? = nil) throws {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)

        print("  Generating \(config.name)...")

        // Package.swift
        try FileWriter.writeFile(
            at: "Package.swift",
            content: CLIPackageSwiftGenerator.generate(config: config),
            basePath: basePath,
        )

        // Main source file
        try FileWriter.writeFile(
            at: "Sources/\(config.name)/\(config.name).swift",
            content: CLIMainGenerator.generate(config: config),
            basePath: basePath,
        )

        // Test file
        try FileWriter.writeFile(
            at: "Tests/\(config.name)Tests/\(config.name)Tests.swift",
            content: TestGenerator.generate(suiteName: config.name.capitalizingFirst, targetName: config.name),
            basePath: basePath,
        )

        // .gitignore
        try FileWriter.writeFile(
            at: ".gitignore",
            content: GitignoreGenerator.generate(options: .init(projectType: .cli)),
            basePath: basePath,
        )

        // README
        try FileWriter.writeFile(
            at: "README.md",
            content: ReadmeGenerator.generateForCLI(config: config),
            basePath: basePath,
        )

        // Optional: Dev tooling
        if config.hasDevTooling {
            try FileWriter.writeToolingFiles(projectType: .cli, basePath: basePath)
        }

        // Optional: CLAUDE.md, LICENSE, CHANGELOG
        try FileWriter.writeOptionalFiles(
            claudeMDContent: config.features.contains(.claudeMD)
                ? ClaudeMDGenerator.generateForCLI(config: config) : nil,
            licenseAuthor: config.features.contains(.licenseChangelog)
                ? config.author : nil,
            basePath: basePath,
        )

        print()
        print("  Done! Run with: swift run \(config.name)")
    }
}
