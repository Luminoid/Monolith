import Foundation

enum AppProjectGenerator {

    static func generate(config: AppConfig) throws {
        let basePath = FileWriter.resolveOutputPath(projectName: config.name)
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
            basePath: basePath
        )
        try FileWriter.writeFile(
            at: "\(appDir)/SceneDelegate.swift",
            content: SceneDelegateGenerator.generate(config: config),
            basePath: basePath
        )

        // Core/
        try FileWriter.writeFile(
            at: "\(coreDir)/AppConstants.swift",
            content: AppConstantsGenerator.generate(config: config),
            basePath: basePath
        )

        // Shared/ViewController or Feature VCs
        if config.hasTabs {
            for tab in config.tabs {
                try FileWriter.writeFile(
                    at: "\(name)/Features/\(tab.name)/\(tab.name)ViewController.swift",
                    content: ViewControllerGenerator.generateForTab(tab, config: config),
                    basePath: basePath
                )
            }
        } else {
            try FileWriter.writeFile(
                at: "\(sharedDir)/ViewController.swift",
                content: ViewControllerGenerator.generate(config: config),
                basePath: basePath
            )
        }

        // Resources/
        let assetsDir = "\(resourcesDir)/Assets.xcassets"
        try FileWriter.writeFile(
            at: "\(assetsDir)/Contents.json",
            content: AssetGenerator.generateContentsJSON(),
            basePath: basePath
        )
        try FileWriter.writeFile(
            at: "\(assetsDir)/AccentColor.colorset/Contents.json",
            content: AssetGenerator.generateAccentColorContents(hex: config.primaryColor),
            basePath: basePath
        )
        try FileWriter.writeFile(
            at: "\(assetsDir)/AppIcon.appiconset/Contents.json",
            content: AssetGenerator.generateAppIconContents(),
            basePath: basePath
        )

        // Info.plist
        try FileWriter.writeFile(
            at: "\(name)/Info.plist",
            content: InfoPlistGenerator.generate(config: config),
            basePath: basePath
        )

        // ExportOptions.plist
        try FileWriter.writeFile(
            at: "ExportOptions.plist",
            content: ExportOptionsGenerator.generate(config: config),
            basePath: basePath
        )

        // Dark Mode (standalone, without LumiKit)
        if config.hasDarkMode, !config.hasLumiKit {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Design/AppTheme.swift",
                content: DarkModeGenerator.generate(config: config),
                basePath: basePath
            )
        }

        // Combine / Async patterns
        if config.hasCombine {
            try FileWriter.writeFile(
                at: "\(coreDir)/Services/DataPublisher.swift",
                content: CombineGenerator.generateDataPublisher(config: config),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(coreDir)/Services/AsyncService.swift",
                content: CombineGenerator.generateAsyncService(config: config),
                basePath: basePath
            )
        }

        // Mac Catalyst
        if config.hasMacCatalyst {
            try FileWriter.writeFile(
                at: "\(name)/MacCatalyst/MacWindowConfig.swift",
                content: MacCatalystGenerator.generateWindowConfig(config: config),
                basePath: basePath
            )
        }

        // Tab Bar Controller
        if config.hasTabs {
            try FileWriter.writeFile(
                at: "\(appDir)/MainTabBarController.swift",
                content: TabBarGenerator.generate(config: config),
                basePath: basePath
            )
        }

        // Theme (LumiKit)
        if config.hasLumiKit {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Design/\(name)Theme.swift",
                content: ThemeGenerator.generate(config: config),
                basePath: basePath
            )
        }

        // Design System
        try FileWriter.writeFile(
            at: "\(sharedDir)/Design/DesignSystem.swift",
            content: DesignSystemGenerator.generate(config: config),
            basePath: basePath
        )

        // SwiftData
        if config.hasSwiftData {
            try FileWriter.writeFile(
                at: "\(coreDir)/Models/SampleItem.swift",
                content: SwiftDataGenerator.generateSampleModel(config: config),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(testsDir)/Helpers/TestContext.swift",
                content: SwiftDataGenerator.generateTestContext(config: config),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(testsDir)/Helpers/TestDataFactory.swift",
                content: SwiftDataGenerator.generateTestDataFactory(config: config),
                basePath: basePath
            )
        }

        // Lottie
        if config.hasLottie {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Components/LottieHelper.swift",
                content: LottieGenerator.generateHelper(config: config),
                basePath: basePath
            )
        }

        // Project system
        switch config.projectSystem {
        case .xcodeGen:
            try FileWriter.writeFile(
                at: "project.yml",
                content: XcodeGenGenerator.generate(config: config),
                basePath: basePath
            )
        case .spm:
            try FileWriter.writeFile(
                at: "Package.swift",
                content: SPMAppGenerator.generate(config: config),
                basePath: basePath
            )
        }

        // Fastlane
        if config.resolvedFeatures.contains(.fastlane) {
            try FileWriter.writeFile(
                at: "Gemfile",
                content: FastlaneGenerator.generateGemfile(),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "fastlane/Appfile",
                content: FastlaneGenerator.generateAppfile(config: config),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "fastlane/Fastfile",
                content: FastlaneGenerator.generateFastfile(config: config),
                basePath: basePath
            )
        }

        // R.swift
        if config.resolvedFeatures.contains(.rSwift) {
            try FileWriter.writeFile(
                at: "Mintfile",
                content: RSwiftGenerator.generateMintfile(),
                basePath: basePath
            )
        }

        // .gitignore
        try FileWriter.writeFile(
            at: ".gitignore",
            content: GitignoreGenerator.generate(options: GitignoreGenerator.Options(
                projectType: .app,
                hasRSwift: config.resolvedFeatures.contains(.rSwift),
                hasFastlane: config.resolvedFeatures.contains(.fastlane),
                appName: config.name
            )),
            basePath: basePath
        )

        // README
        try FileWriter.writeFile(
            at: "README.md",
            content: ReadmeGenerator.generateForApp(config: config),
            basePath: basePath
        )

        // Tests placeholder
        try FileWriter.writeFile(
            at: "\(testsDir)/\(name)Tests.swift",
            content: generateTestPlaceholder(config: config),
            basePath: basePath
        )

        // Optional features
        if config.resolvedFeatures.contains(.devTooling) {
            try writeToolingFiles(config: config, basePath: basePath)
        }

        if config.resolvedFeatures.contains(.claudeMD) {
            try FileWriter.writeFile(
                at: ".claude/CLAUDE.md",
                content: ClaudeMDGenerator.generateForApp(config: config),
                basePath: basePath
            )
        }

        if config.resolvedFeatures.contains(.licenseChangelog) {
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

        print("\n  \(config.name) app created at \(basePath)")
    }

    // MARK: - Helpers

    private static func generateTestPlaceholder(config: AppConfig) -> String {
        """
        import Foundation
        import Testing

        @Suite("\(config.name)")
        struct \(config.name)Tests {

            @Test("app launches")
            func appLaunches() {
                // Add tests here
                #expect(true)
            }
        }
        """
    }

    private static func writeToolingFiles(config: AppConfig, basePath: String) throws {
        let hasRSwift = config.resolvedFeatures.contains(.rSwift)
        let hasFastlane = config.resolvedFeatures.contains(.fastlane)

        try FileWriter.writeFile(
            at: ".swiftlint.yml",
            content: ToolingGenerator.generateSwiftLint(
                projectType: .app, appName: config.name,
                hasRSwift: hasRSwift, hasFastlane: hasFastlane
            ),
            basePath: basePath
        )
        try FileWriter.writeFile(
            at: ".swiftformat",
            content: ToolingGenerator.generateSwiftFormat(),
            basePath: basePath
        )
        try FileWriter.writeFile(
            at: "Makefile",
            content: ToolingGenerator.generateMakefile(
                projectType: .app, appName: config.name, hasFastlane: hasFastlane
            ),
            basePath: basePath
        )
        try FileWriter.writeFile(
            at: "Brewfile",
            content: ToolingGenerator.generateBrewfile(
                projectSystem: config.projectSystem, hasRSwift: hasRSwift
            ),
            basePath: basePath
        )
    }
}
