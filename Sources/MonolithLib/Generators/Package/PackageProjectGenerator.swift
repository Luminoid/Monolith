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
                content: PackageSourceGenerator.generateTest(targetName: target.name),
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
            try FileWriter.writeFile(
                at: ".swiftlint.yml",
                content: ToolingGenerator.generateSwiftLint(projectType: .package),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: ".swiftformat",
                content: ToolingGenerator.generateSwiftFormat(),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "Makefile",
                content: ToolingGenerator.generateMakefile(projectType: .package),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "Brewfile",
                content: ToolingGenerator.generateBrewfile(),
                basePath: basePath
            )
        }

        // Optional: CLAUDE.md
        if config.features.contains(.claudeMD) {
            try FileWriter.writeFile(
                at: ".claude/CLAUDE.md",
                content: ClaudeMDGenerator.generateForPackage(config: config),
                basePath: basePath
            )
        }

        // Optional: LICENSE + CHANGELOG
        if config.features.contains(.licenseChangelog) {
            try FileWriter.writeFile(
                at: "LICENSE",
                content: LicenseChangelogGenerator.generateLicense(author: config.author),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "CHANGELOG.md",
                content: LicenseChangelogGenerator.generateChangelog(),
                basePath: basePath
            )
        }

        print()
        print("  Done!")
    }
}
