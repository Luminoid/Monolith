import Foundation

/// The `--dry-run` preview of `new`: the files each project generator would
/// write, listed without touching the disk. Each `planned*Files` function
/// mirrors its generator one block at a time, and tests diff the two.
enum DryRunPlanner {
    /// Preview files that would be generated for an app config.
    static func printDryRun(config: AppConfig, outputDir: String? = nil) {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)
        printFileList(basePath: basePath, files: plannedAppFiles(config: config))
    }

    /// The relative paths `AppProjectGenerator.generate` writes for a given
    /// config. Kept as a standalone function (rather than inlined into the
    /// dry-run print) so it mirrors `AppProjectGenerator` one block at a time
    /// and a regression test can assert dry-run == real-generation parity.
    ///
    /// IMPORTANT: this must stay in lockstep with `AppProjectGenerator.generate`.
    /// Every `FileWriter.writeFile` there that emits a NEW path needs a matching
    /// entry here. `DryRunPlannerTests` diffs this against a real generation
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

        // Design + services
        if config.hasDarkMode, !config.hasLumiKit { files.append("\(sharedDir)/Design/AppTheme.swift") }
        if config.hasCombine { files.append("\(coreDir)/Services/AsyncService.swift") }
        if config.hasMacCatalyst, !config.hasLumiKit { files.append("\(name)/MacCatalyst/MacWindowConfig.swift") }
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

        // App target entitlements: written whenever a feature needs capability
        // keys — App Group (widget) or iCloud container + CloudKit + APNs
        // (cloudKit). Mirrors the union gate in AppProjectGenerator. A Mac
        // Catalyst app always gets its sandboxed Mac file.
        if config.hasWidget || config.hasCloudKit {
            files.append(EntitlementsGenerator.appPath(appName: name))
        }
        if config.hasMacCatalyst {
            files.append(EntitlementsGenerator.macCatalystPath(appName: name))
        }

        // Widget extension: the widget target's files + the widget's own
        // (always-on) PrivacyInfo. The App Group entitlements on the app target
        // are written above (the union gate).
        if config.hasWidget {
            files += WidgetExtensionGenerator.files(appName: name, appGroup: config.appGroupIdentifier).map(\.path)
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

        // Project system (the .xcodeproj bundle is one logical entry). Apps
        // reject SPM before planning, so anything but `.xcodeProj` keeps
        // project.yml.
        files.append(config.projectSystem == .xcodeProj ? "\(name).xcodeproj" : "project.yml")

        if config.hasFastlane {
            files.append(contentsOf: ["Gemfile", "fastlane/Appfile", "fastlane/Fastfile", "ExportOptions.plist"])
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
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)
        printFileList(basePath: basePath, files: plannedPackageFiles(config: config))
    }

    /// Every file `PackageProjectGenerator` writes for `config` (resource
    /// `.gitkeep` placeholders aside), in write order.
    static func plannedPackageFiles(config: PackageConfig) -> [String] {
        var files = ["Package.swift"]

        for target in config.targets {
            let dir = PackageSwiftGenerator.sourceDirectoryName(for: target)
            files.append("Sources/\(dir)/\(dir).swift")
            if !PackageSwiftGenerator.shouldSkipTestTarget(target, config: config) {
                files.append("Tests/\(target.name)Tests/\(target.name)Tests.swift")
            }
        }
        if let logCore = LogCoreGenerator.placement(for: config.mergingRequiredPlatforms()) {
            files.append(contentsOf: logCore.paths)
        }

        files.append(contentsOf: [".gitignore", "README.md"])
        if config.hasDevTooling { files.append(contentsOf: [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]) }
        if config.hasGitHooks { files.append("Scripts/git-hooks/pre-commit") }
        if config.features.contains(.claudeMD) { files.append(".claude/CLAUDE.md") }
        if config.features.contains(.licenseChangelog) { files.append(contentsOf: ["LICENSE", "CHANGELOG.md"]) }

        return files
    }

    /// Preview files that would be generated for a CLI config.
    static func printDryRun(config: CLIConfig, outputDir: String? = nil) {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)
        printFileList(basePath: basePath, files: plannedCLIFiles(config: config))
    }

    /// Every file `CLIProjectGenerator` writes for `config`, in write order.
    /// `CLIDryRunTests` diffs this against a real generation.
    static func plannedCLIFiles(config: CLIConfig) -> [String] {
        var files: [String] = [
            "Package.swift",
            CLIMainGenerator.librarySourcePath(config: config),
            CLIMainGenerator.mainPath(config: config),
            CLIMainGenerator.testsPath(config: config),
            ".gitignore",
            "README.md",
        ]

        if config.hasDevTooling { files.append(contentsOf: [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]) }
        if config.hasGitHooks { files.append("Scripts/git-hooks/pre-commit") }
        if config.features.contains(.claudeMD) { files.append(".claude/CLAUDE.md") }
        if config.features.contains(.licenseChangelog) { files.append(contentsOf: ["LICENSE", "CHANGELOG.md"]) }

        return files
    }

    private static func printFileList(basePath: String, files: [String]) {
        print("  Dry run: \(files.count) files would be created at \(basePath)\n")
        for file in files {
            print("    \(file)")
        }
    }
}
