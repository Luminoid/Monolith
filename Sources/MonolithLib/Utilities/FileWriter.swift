import Foundation

enum FileWriter {
    /// Write a file at the given relative path under the base directory.
    /// Creates intermediate directories as needed. Optionally sets executable permission.
    static func writeFile(at relativePath: String, content: String, basePath: String, executable: Bool = false) throws {
        // Reject absolute paths and any segment that walks above the basePath.
        // Every current caller hardcodes a literal relative path (e.g.
        // "Sources/Foo.swift"), so a `..` or leading `/` is always a bug —
        // probably a missing trim of an absolute basePath that got passed
        // through as the relative arg. Catching it here keeps generators from
        // silently writing outside the project root if a future feature ever
        // surfaces user-supplied paths (e.g. a `--output-path <file>` knob).
        let segments = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        if relativePath.hasPrefix("/") || segments.contains("..") {
            throw FileWriterError.invalidRelativePath(relativePath)
        }
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        let directory = (fullPath as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try content.write(toFile: fullPath, atomically: true, encoding: .utf8)

        if executable {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: fullPath
            )
        }

        print("  \(UISymbols.check) \(relativePath)")
    }

    /// Resolve the output base path: currentDirectory/projectName.
    static func resolveOutputPath(projectName: String, outputDir: String? = nil) -> String {
        let base = outputDir ?? FileManager.default.currentDirectoryPath
        return (base as NSString).appendingPathComponent(projectName)
    }

    /// Get the git author name, or nil if not configured.
    static func gitAuthorName() -> String? {
        ShellRunner.runCapturingStdout(
            executable: "/usr/bin/git",
            arguments: ["config", "user.name"]
        )
    }

    // MARK: - Shared File Groups

    /// Write dev tooling files (.swiftlint.yml, .swiftformat, Makefile, Brewfile).
    static func writeToolingFiles(
        projectType: ProjectType,
        appName: String? = nil,
        hasRSwift: Bool = false,
        hasFastlane: Bool = false,
        hasGitHooks: Bool = false,
        hasDefaultIsolation: Bool = false,
        hasLocalization: Bool = false,
        hasAppIconValidation: Bool = false,
        projectSystem: ProjectSystem? = nil,
        basePath: String,
        xcodeBuildScheme: String? = nil,
        disableTestParallelism: Bool = false
    ) throws {
        try writeFile(
            at: ".swiftlint.yml",
            content: SwiftLintGenerator.generate(
                projectType: projectType, appName: appName,
                hasRSwift: hasRSwift, hasFastlane: hasFastlane
            ),
            basePath: basePath
        )
        try writeFile(
            at: ".swiftformat",
            content: SwiftFormatGenerator.generate(),
            basePath: basePath
        )
        try writeFile(
            at: "Makefile",
            content: MakefileGenerator.generate(
                projectType: projectType, appName: appName,
                hasFastlane: hasFastlane, hasGitHooks: hasGitHooks,
                hasDefaultIsolation: hasDefaultIsolation,
                hasLocalization: hasLocalization,
                hasAppIconValidation: hasAppIconValidation,
                projectSystem: projectSystem,
                xcodeBuildScheme: xcodeBuildScheme,
                disableTestParallelism: disableTestParallelism
            ),
            basePath: basePath
        )
        try writeFile(
            at: "Brewfile",
            content: BrewfileGenerator.generate(
                projectSystem: projectSystem, hasRSwift: hasRSwift
            ),
            basePath: basePath
        )
    }

    /// Write git hooks (pre-commit script).
    static func writeGitHooks(
        basePath: String,
        options: GitHooksGenerator.Options = .basic
    ) throws {
        try writeFile(
            at: "Scripts/git-hooks/pre-commit",
            content: GitHooksGenerator.generatePreCommitHook(options: options),
            basePath: basePath,
            executable: true
        )
    }

    /// Write optional CLAUDE.md, LICENSE, and CHANGELOG files.
    static func writeOptionalFiles(
        claudeMDContent: String?,
        licenseAuthor: String?,
        licenseType: LicenseType = .mit,
        basePath: String
    ) throws {
        if let content = claudeMDContent {
            try writeFile(at: ".claude/CLAUDE.md", content: content, basePath: basePath)
        }
        if let author = licenseAuthor {
            try writeFile(
                at: "LICENSE",
                content: LicenseChangelogGenerator.generateLicense(author: author, type: licenseType),
                basePath: basePath
            )
            try writeFile(
                at: "CHANGELOG.md",
                content: LicenseChangelogGenerator.generateChangelog(),
                basePath: basePath
            )
        }
    }

    // MARK: - Dry Run

    /// Preview files that would be generated for an app config.
    static func printDryRun(config: AppConfig, outputDir: String? = nil) {
        let basePath = resolveOutputPath(projectName: config.name, outputDir: outputDir)
        let name = config.name
        var files: [String] = []

        files.append("\(name)/App/AppDelegate.swift")
        files.append("\(name)/App/SceneDelegate.swift")
        files.append("\(name)/Core/AppConstants.swift")

        if config.hasTabs {
            for tab in config.tabs {
                files.append("\(name)/Features/\(tab.name)/\(tab.name)ViewController.swift")
            }
            files.append("\(name)/App/MainTabBarController.swift")
        } else {
            files.append("\(name)/Shared/ViewController.swift")
        }

        files.append("\(name)/Resources/Assets.xcassets/Contents.json")
        files.append("\(name)/Resources/Assets.xcassets/AccentColor.colorset/Contents.json")
        files.append("\(name)/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json")
        files.append("\(name)/Info.plist")
        files.append("ExportOptions.plist")

        if config.hasDarkMode, !config.hasLumiKit { files.append("\(name)/Shared/Design/AppTheme.swift") }
        if config.hasCombine {
            files.append("\(name)/Core/Services/AsyncService.swift")
        }
        if config.hasMacCatalyst { files.append("\(name)/MacCatalyst/MacWindowConfig.swift") }
        if config.hasLumiKit { files.append("\(name)/Shared/Design/\(name)Theme.swift") }
        files.append("\(name)/Shared/Design/DesignSystem.swift")
        if config.hasSwiftData {
            files.append("\(name)/Core/Models/SampleItem.swift")
            files.append("\(name)Tests/Helpers/TestContext.swift")
            files.append("\(name)Tests/Helpers/TestDataFactory.swift")
        }
        if config.hasLocalization {
            files.append("\(name)/Resources/Localizable.xcstrings")
            files.append("\(name)/Core/L10n.swift")
            files.append("Scripts/localization/audit_strings.py")
        }
        if config.hasLottie { files.append("\(name)/Shared/Components/LottieHelper.swift") }

        switch config.projectSystem {
        case .xcodeProj: files.append("\(name).xcodeproj")
        case .xcodeGen: files.append("project.yml")
        case .spm: files.append("Package.swift")
        }

        if config.hasFastlane {
            files.append(contentsOf: ["Gemfile", "fastlane/Appfile", "fastlane/Fastfile"])
        }
        if config.hasRSwift { files.append("Mintfile") }
        files.append(".gitignore")
        files.append("README.md")
        files.append("\(name)Tests/\(name)Tests.swift")
        if config.hasDevTooling { files.append(contentsOf: [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]) }
        if config.hasGitHooks { files.append("Scripts/git-hooks/pre-commit") }
        if config.hasClaudeMD { files.append(".claude/CLAUDE.md") }
        if config.hasLicenseChangelog { files.append(contentsOf: ["LICENSE", "CHANGELOG.md"]) }

        printFileList(basePath: basePath, files: files)
    }

    /// Preview files that would be generated for a package config.
    static func printDryRun(config: PackageConfig, outputDir: String? = nil) {
        let basePath = resolveOutputPath(projectName: config.name, outputDir: outputDir)
        var files = ["Package.swift"]

        for target in config.targets {
            let dir = PackageSwiftGenerator.sourceDirectoryName(for: target)
            files.append("Sources/\(dir)/\(dir).swift")
            if !PackageSwiftGenerator.shouldSkipTestTarget(target, config: config) {
                files.append("Tests/\(target.name)Tests/\(target.name)Tests.swift")
            }
        }

        files.append(contentsOf: [".gitignore", "README.md"])
        if config.hasDevTooling { files.append(contentsOf: [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]) }
        if config.hasGitHooks { files.append("Scripts/git-hooks/pre-commit") }
        if config.features.contains(.claudeMD) { files.append(".claude/CLAUDE.md") }
        if config.features.contains(.licenseChangelog) { files.append(contentsOf: ["LICENSE", "CHANGELOG.md"]) }

        printFileList(basePath: basePath, files: files)
    }

    /// Preview files that would be generated for a CLI config.
    static func printDryRun(config: CLIConfig, outputDir: String? = nil) {
        let basePath = resolveOutputPath(projectName: config.name, outputDir: outputDir)
        var files: [String] = [
            "Package.swift",
            "Sources/\(config.name)/\(config.name).swift",
            "Tests/\(config.name)Tests/\(config.name)Tests.swift",
            ".gitignore",
            "README.md",
        ]

        if config.hasDevTooling { files.append(contentsOf: [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]) }
        if config.hasGitHooks { files.append("Scripts/git-hooks/pre-commit") }
        if config.features.contains(.claudeMD) { files.append(".claude/CLAUDE.md") }
        if config.features.contains(.licenseChangelog) { files.append(contentsOf: ["LICENSE", "CHANGELOG.md"]) }

        printFileList(basePath: basePath, files: files)
    }

    private static func printFileList(basePath: String, files: [String]) {
        print("  Dry run — \(files.count) files would be created at \(basePath):\n")
        for file in files {
            print("    \(file)")
        }
    }

    /// Initialize a git repository and create an initial commit.
    /// When `hasGitHooks` is true, configures `core.hooksPath` to use shared hooks.
    @discardableResult
    static func gitInit(at path: String, hasGitHooks: Bool = false) -> Bool {
        var commands: [(args: [String], label: String)] = [
            (["init"], "git init"),
            (["add", "."], "git add"),
            (["commit", "-m", "Initial commit"], "git commit"),
        ]

        if hasGitHooks {
            commands.append(
                (["config", "core.hooksPath", "Scripts/git-hooks"], "git hooks path")
            )
        }

        for command in commands {
            let ok = ShellRunner.runDiscardingOutput(
                executable: "/usr/bin/git",
                arguments: command.args,
                cwd: path,
                failureLabel: "\(command.label) failed"
            )
            guard ok else { return false }
        }

        print("  \(UISymbols.check) git repository initialized")
        return true
    }
}

enum FileWriterError: Error, CustomStringConvertible {
    case invalidRelativePath(String)

    var description: String {
        switch self {
        case let .invalidRelativePath(path):
            "FileWriter rejected path '\(path)': must be relative and contain no '..' segments"
        }
    }
}
