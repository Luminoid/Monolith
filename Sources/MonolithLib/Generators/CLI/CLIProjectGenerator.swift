import Foundation

enum CLIProjectGenerator {
    /// Writes the CLI project. `DryRunPlanner.plannedCLIFiles` lists the same
    /// paths in the same order for `--dry-run`; keep the two in lockstep.
    static func generate(config: CLIConfig, outputDir: String? = nil) throws {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)

        print("  Generating \(config.name)...")

        // Package.swift
        try FileWriter.writeFile(
            at: "Package.swift",
            content: CLIPackageSwiftGenerator.generate(config: config),
            basePath: basePath
        )

        // Library: the command itself
        try FileWriter.writeFile(
            at: CLIMainGenerator.librarySourcePath(config: config),
            content: CLIMainGenerator.generate(config: config),
            basePath: basePath
        )

        // Executable: main.swift calls into the library
        try FileWriter.writeFile(
            at: CLIMainGenerator.mainPath(config: config),
            content: CLIMainGenerator.generateMain(config: config),
            basePath: basePath
        )

        // Tests import the library
        try FileWriter.writeFile(
            at: CLIMainGenerator.testsPath(config: config),
            content: CLIMainGenerator.generateTests(config: config),
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
            try FileWriter.writeToolingFiles(
                projectType: .cli, hasGitHooks: config.hasGitHooks, basePath: basePath
            )
        }

        // Optional: Git hooks
        if config.hasGitHooks {
            try FileWriter.writeGitHooks(basePath: basePath)
        }

        // Optional: CLAUDE.md, LICENSE, CHANGELOG
        try FileWriter.writeOptionalFiles(
            claudeMDContent: config.features.contains(.claudeMD)
                ? ClaudeMDGenerator.generateForCLI(config: config, includeLayout: true) : nil,
            licenseAuthor: config.features.contains(.licenseChangelog)
                ? config.author : nil,
            licenseType: config.licenseType,
            projectName: config.name,
            basePath: basePath
        )
    }

    /// The post-generation setup steps. `make setup-hooks` needs the Makefile
    /// that dev tooling writes; without it, the hooks path is set directly.
    /// `NewCommandRunner` prints them for every project type, after git init.
    static func nextSteps(hasDevTooling: Bool, hasGitHooks: Bool) -> [String] {
        var steps: [String] = []
        if hasDevTooling {
            steps.append("brew bundle")
        }
        if hasGitHooks {
            steps.append(hasDevTooling ? "make setup-hooks" : "git config core.hooksPath Scripts/git-hooks")
        }
        return steps
    }
}
