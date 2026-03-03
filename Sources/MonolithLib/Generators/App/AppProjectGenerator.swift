import Foundation

enum AppProjectGenerator {
    static func generate(config: AppConfig, outputDir: String? = nil) throws {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: outputDir)
        let name = config.name
        let appDir = "\(name)/App"
        let coreDir = "\(name)/Core"
        let sharedDir = "\(name)/Shared"
        let resourcesDir = "\(name)/Resources"
        let testsDir = "\(name)Tests"

        // App/
        try FileWriter.writeFile(
            at: "\(appDir)/AppDelegate.swift",
            content: AppDelegateGenerator.generate(config: config),
            basePath: basePath,
        )
        try FileWriter.writeFile(
            at: "\(appDir)/SceneDelegate.swift",
            content: SceneDelegateGenerator.generate(config: config),
            basePath: basePath,
        )

        // Core/
        try FileWriter.writeFile(
            at: "\(coreDir)/AppConstants.swift",
            content: AppConstantsGenerator.generate(config: config),
            basePath: basePath,
        )

        // Shared/ViewController or Feature VCs
        if config.hasTabs {
            for tab in config.tabs {
                try FileWriter.writeFile(
                    at: "\(name)/Features/\(tab.name)/\(tab.name)ViewController.swift",
                    content: ViewControllerGenerator.generateForTab(tab, config: config),
                    basePath: basePath,
                )
            }
        } else {
            try FileWriter.writeFile(
                at: "\(sharedDir)/ViewController.swift",
                content: ViewControllerGenerator.generate(config: config),
                basePath: basePath,
            )
        }

        // Resources/
        let assetsDir = "\(resourcesDir)/Assets.xcassets"
        try FileWriter.writeFile(
            at: "\(assetsDir)/Contents.json",
            content: AssetGenerator.generateContentsJSON(),
            basePath: basePath,
        )
        try FileWriter.writeFile(
            at: "\(assetsDir)/AccentColor.colorset/Contents.json",
            content: AssetGenerator.generateAccentColorContents(hex: config.primaryColor),
            basePath: basePath,
        )
        try FileWriter.writeFile(
            at: "\(assetsDir)/AppIcon.appiconset/Contents.json",
            content: AssetGenerator.generateAppIconContents(),
            basePath: basePath,
        )

        // Info.plist
        try FileWriter.writeFile(
            at: "\(name)/Info.plist",
            content: InfoPlistGenerator.generate(),
            basePath: basePath,
        )

        // ExportOptions.plist
        try FileWriter.writeFile(
            at: "ExportOptions.plist",
            content: ExportOptionsGenerator.generate(),
            basePath: basePath,
        )

        // Dark Mode (standalone, without LumiKit)
        if config.hasDarkMode, !config.hasLumiKit {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Design/AppTheme.swift",
                content: DarkModeGenerator.generate(config: config),
                basePath: basePath,
            )
        }

        // Combine / Async patterns
        if config.hasCombine {
            try FileWriter.writeFile(
                at: "\(coreDir)/Services/DataPublisher.swift",
                content: CombineGenerator.generateDataPublisher(),
                basePath: basePath,
            )
            try FileWriter.writeFile(
                at: "\(coreDir)/Services/AsyncService.swift",
                content: CombineGenerator.generateAsyncService(),
                basePath: basePath,
            )
        }

        // Mac Catalyst
        if config.hasMacCatalyst {
            try FileWriter.writeFile(
                at: "\(name)/MacCatalyst/MacWindowConfig.swift",
                content: MacCatalystGenerator.generateWindowConfig(),
                basePath: basePath,
            )
        }

        // Tab Bar Controller
        if config.hasTabs {
            try FileWriter.writeFile(
                at: "\(appDir)/MainTabBarController.swift",
                content: TabBarGenerator.generate(config: config),
                basePath: basePath,
            )
        }

        // Theme (LumiKit)
        if config.hasLumiKit {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Design/\(name)Theme.swift",
                content: ThemeGenerator.generate(config: config),
                basePath: basePath,
            )
        }

        // Design System
        try FileWriter.writeFile(
            at: "\(sharedDir)/Design/DesignSystem.swift",
            content: DesignSystemGenerator.generate(),
            basePath: basePath,
        )

        // SwiftData
        if config.hasSwiftData {
            try FileWriter.writeFile(
                at: "\(coreDir)/Models/SampleItem.swift",
                content: SwiftDataGenerator.generateSampleModel(config: config),
                basePath: basePath,
            )
            try FileWriter.writeFile(
                at: "\(testsDir)/Helpers/TestContext.swift",
                content: SwiftDataGenerator.generateTestContext(config: config),
                basePath: basePath,
            )
            try FileWriter.writeFile(
                at: "\(testsDir)/Helpers/TestDataFactory.swift",
                content: SwiftDataGenerator.generateTestDataFactory(config: config),
                basePath: basePath,
            )
        }

        // Localization
        if config.hasLocalization {
            try FileWriter.writeFile(
                at: "\(resourcesDir)/Localizable.xcstrings",
                content: LocalizationGenerator.generateStringCatalog(config: config),
                basePath: basePath,
            )
            try FileWriter.writeFile(
                at: "\(coreDir)/L10n.swift",
                content: LocalizationGenerator.generateL10n(config: config),
                basePath: basePath,
            )
        }

        // Lottie
        if config.hasLottie {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Components/LottieHelper.swift",
                content: LottieGenerator.generateHelper(),
                basePath: basePath,
            )
        }

        // Project system
        switch config.projectSystem {
        case .xcodeGen:
            try FileWriter.writeFile(
                at: "project.yml",
                content: XcodeGenGenerator.generate(config: config),
                basePath: basePath,
            )
        case .spm:
            try FileWriter.writeFile(
                at: "Package.swift",
                content: SPMAppGenerator.generate(config: config),
                basePath: basePath,
            )
        }

        // Fastlane
        if config.resolvedFeatures.contains(.fastlane) {
            try FileWriter.writeFile(
                at: "Gemfile",
                content: FastlaneGenerator.generateGemfile(),
                basePath: basePath,
            )
            try FileWriter.writeFile(
                at: "fastlane/Appfile",
                content: FastlaneGenerator.generateAppfile(config: config),
                basePath: basePath,
            )
            try FileWriter.writeFile(
                at: "fastlane/Fastfile",
                content: FastlaneGenerator.generateFastfile(config: config),
                basePath: basePath,
            )
        }

        // R.swift
        if config.resolvedFeatures.contains(.rSwift) {
            try FileWriter.writeFile(
                at: "Mintfile",
                content: RSwiftGenerator.generateMintfile(),
                basePath: basePath,
            )
        }

        // .gitignore
        try FileWriter.writeFile(
            at: ".gitignore",
            content: GitignoreGenerator.generate(options: GitignoreGenerator.Options(
                projectType: .app,
                hasRSwift: config.resolvedFeatures.contains(.rSwift),
                hasFastlane: config.resolvedFeatures.contains(.fastlane),
                appName: config.name,
            )),
            basePath: basePath,
        )

        // README
        try FileWriter.writeFile(
            at: "README.md",
            content: ReadmeGenerator.generateForApp(config: config),
            basePath: basePath,
        )

        // Tests placeholder
        try FileWriter.writeFile(
            at: "\(testsDir)/\(name)Tests.swift",
            content: TestGenerator.generateAppTest(suiteName: config.name),
            basePath: basePath,
        )

        // Optional features
        if config.hasDevTooling {
            try FileWriter.writeToolingFiles(
                projectType: .app,
                appName: config.name,
                hasRSwift: config.resolvedFeatures.contains(.rSwift),
                hasFastlane: config.resolvedFeatures.contains(.fastlane),
                hasGitHooks: config.hasGitHooks,
                projectSystem: config.projectSystem,
                basePath: basePath,
            )
        }

        if config.hasGitHooks {
            try FileWriter.writeGitHooks(basePath: basePath)
        }

        try FileWriter.writeOptionalFiles(
            claudeMDContent: config.resolvedFeatures.contains(.claudeMD)
                ? ClaudeMDGenerator.generateForApp(config: config) : nil,
            licenseAuthor: config.resolvedFeatures.contains(.licenseChangelog)
                ? config.author : nil,
            basePath: basePath,
        )

        print("\n  \(config.name) app created at \(basePath)")
    }
}
