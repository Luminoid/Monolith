import Foundation

enum CLIProjectGenerator {

    static func generate(config: CLIConfig, outputDir: String? = nil) throws {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)

        print("  Generating \(config.name)...")

        // Package.swift
        try FileWriter.writeFile(
            at: "Package.swift",
            content: CLIPackageSwiftGenerator.generate(config: config),
            basePath: basePath
        )

        // Main source file
        try FileWriter.writeFile(
            at: "Sources/\(config.name)/\(config.name).swift",
            content: CLIMainGenerator.generate(config: config),
            basePath: basePath
        )

        // Test file
        try FileWriter.writeFile(
            at: "Tests/\(config.name)Tests/\(config.name)Tests.swift",
            content: generateTestFile(config: config),
            basePath: basePath
        )

        // .gitignore
        try FileWriter.writeFile(
            at: ".gitignore",
            content: GitignoreGenerator.generate(options: .init(projectType: .cli)),
            basePath: basePath
        )

        // README
        try FileWriter.writeFile(
            at: "README.md",
            content: ReadmeGenerator.generateForCLI(config: config),
            basePath: basePath
        )

        // Optional: Dev tooling
        if config.hasDevTooling {
            try FileWriter.writeFile(
                at: ".swiftlint.yml",
                content: ToolingGenerator.generateSwiftLint(projectType: .cli),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: ".swiftformat",
                content: ToolingGenerator.generateSwiftFormat(),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "Makefile",
                content: ToolingGenerator.generateMakefile(projectType: .cli),
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
                content: ClaudeMDGenerator.generateForCLI(config: config),
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
        print("  Done! Run with: swift run \(config.name)")
    }

    private static func generateTestFile(config: CLIConfig) -> String {
        """
        import Foundation
        import Testing
        @testable import \(config.name)

        @Suite("\(config.name.capitalizingFirst)")
        struct \(config.name.capitalizingFirst)Tests {
            @Test("runs successfully")
            func runs() {
                // Add your tests here
                #expect(true)
            }
        }

        """
    }
}
