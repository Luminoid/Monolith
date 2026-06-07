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
        printFileList(basePath: basePath, files: plannedAppFiles(config: config))
    }

    /// The relative paths `AppProjectGenerator.generate` writes for a given
    /// config. Kept as a standalone function (rather than inlined into the
    /// dry-run print) so it mirrors `AppProjectGenerator` one block at a time
    /// and a regression test can assert dry-run == real-generation parity.
    ///
    /// IMPORTANT: this must stay in lockstep with `AppProjectGenerator.generate`.
    /// Every `FileWriter.writeFile` there that emits a NEW path needs a matching
    /// entry here. `FileWriterDryRunTests` diffs this against a real generation
    /// for a feature-rich config, so an omission fails the suite. The `.xcodeproj`
    /// bundle is intentionally collapsed to a single entry (the generator runs
    /// xcodegen, which writes the bundle's internals).
    static func plannedAppFiles(config: AppConfig) -> [String] {
        plannedAppBaseFiles(config: config)
            + plannedAppFeatureFiles(config: config)
            + plannedAppInfrastructureFiles(config: config)
    }

    /// App/ + Core/ + Resources/ + the always-written design layer.
    private static func plannedAppBaseFiles(config: AppConfig) -> [String] {
        let name = config.name
        let appDir = "\(name)/App"
        let coreDir = "\(name)/Core"
        let sharedDir = "\(name)/Shared"
        let assetsDir = "\(name)/Resources/Assets.xcassets"
        var files: [String] = []

        // App/ + Core/
        files.append("\(appDir)/AppDelegate.swift")
        files.append("\(appDir)/SceneDelegate.swift")
        files.append("\(coreDir)/AppConstants.swift")

        // Feature VCs (tabs) or a standalone ViewController + Features/.gitkeep
        if config.hasTabs {
            for tab in config.tabs {
                files.append("\(name)/Features/\(tab.name)/\(tab.name)ViewController.swift")
            }
        } else {
            files.append("\(sharedDir)/ViewController.swift")
            files.append("\(name)/Features/.gitkeep")
        }

        // Empty Core/Models/ when no persistence layer seeds a model.
        if !config.hasSwiftData, !config.hasCoreData {
            files.append("\(coreDir)/Models/.gitkeep")
        }

        // Resources/
        files.append("\(assetsDir)/Contents.json")
        files.append("\(assetsDir)/AccentColor.colorset/Contents.json")
        files.append("\(assetsDir)/AppIcon.appiconset/Contents.json")
        files.append("\(name)/Info.plist")
        files.append("ExportOptions.plist")

        // Design + services
        if config.hasDarkMode, !config.hasLumiKit { files.append("\(sharedDir)/Design/AppTheme.swift") }
        if config.hasCombine { files.append("\(coreDir)/Services/AsyncService.swift") }
        if config.hasMacCatalyst { files.append("\(name)/MacCatalyst/MacWindowConfig.swift") }
        if config.hasTabs { files.append("\(appDir)/MainTabBarController.swift") }
        if config.hasLumiKit { files.append("\(sharedDir)/Design/\(name)Theme.swift") }
        files.append("\(sharedDir)/Design/DesignSystem.swift")

        return files
    }

    /// Feature-conditional outputs: persistence, App Store hygiene, the widget
    /// extension, localization, Lottie, and the always-written test source.
    private static func plannedAppFeatureFiles(config: AppConfig) -> [String] {
        let name = config.name
        let coreDir = "\(name)/Core"
        let sharedDir = "\(name)/Shared"
        let resourcesDir = "\(name)/Resources"
        let testsDir = "\(name)Tests"
        var files: [String] = []

        // Persistence: SwiftData seeds a SampleItem; Core Data seeds the model
        // + stack; both seed the test helpers (listed once even though the
        // generator writes them under each block to the same paths).
        if config.hasSwiftData {
            files.append("\(coreDir)/Models/SampleItem.swift")
        }
        if config.hasCoreData {
            let modelDir = "\(coreDir)/Models/\(name).xcdatamodeld"
            files.append("\(modelDir)/\(name).xcdatamodel/contents")
            files.append("\(modelDir)/.xccurrentversion")
            files.append("\(coreDir)/Persistence/\(name)CoreDataStack.swift")
        }
        if config.hasSwiftData || config.hasCoreData {
            files.append("\(testsDir)/Helpers/TestContext.swift")
            files.append("\(testsDir)/Helpers/TestDataFactory.swift")
        }

        // Privacy manifest (app bundle)
        if config.hasPrivacyManifest { files.append("\(resourcesDir)/PrivacyInfo.xcprivacy") }

        // App-icon alpha validation build-phase script
        if config.hasAppIconValidation { files.append("Scripts/validate-app-icon.sh") }

        // Widget extension: App Group entitlements on the app target + the
        // widget target's files + the widget's own (always-on) PrivacyInfo.
        if config.hasWidget {
            let widgetDir = "\(name)Widget"
            files.append("\(name)/\(name).entitlements")
            files.append("\(widgetDir)/Info.plist")
            files.append("\(widgetDir)/\(name)Widget.entitlements")
            files.append("\(widgetDir)/\(name)WidgetBundle.swift")
            files.append("\(widgetDir)/\(name)Widget.swift")
            files.append("\(sharedDir)/AppGroup.swift")
            files.append("\(widgetDir)/PrivacyInfo.xcprivacy")
        }

        // Localization
        if config.hasLocalization {
            files.append("\(resourcesDir)/Localizable.xcstrings")
            files.append("\(coreDir)/L10n.swift")
            files.append("Scripts/localization/audit_strings.py")
        }

        if config.hasLottie { files.append("\(sharedDir)/Components/LottieHelper.swift") }

        // Test target source (always written)
        files.append("\(testsDir)/\(name)Tests.swift")

        return files
    }

    /// Project-system file + repo/tooling infrastructure.
    private static func plannedAppInfrastructureFiles(config: AppConfig) -> [String] {
        let name = config.name
        var files: [String] = []

        // Project system (the .xcodeproj bundle is one logical entry)
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
        if config.hasDevTooling { files.append(contentsOf: [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]) }
        if config.hasGitHooks { files.append("Scripts/git-hooks/pre-commit") }
        if config.hasClaudeMD { files.append(".claude/CLAUDE.md") }
        if config.hasLicenseChangelog { files.append(contentsOf: ["LICENSE", "CHANGELOG.md"]) }

        return files
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
