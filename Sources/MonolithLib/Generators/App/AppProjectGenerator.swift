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
            // README's "next steps" mentions building feature view controllers
            // in `Features/`, but without tabs the dir wouldn't exist. Seed an
            // empty `.gitkeep` so the path the docs reference is real.
            try FileWriter.writeFile(
                at: "\(name)/Features/.gitkeep",
                content: "",
                basePath: basePath
            )
        }

        // Seed an empty `Core/Models/` when no persistence layer generates a
        // SampleItem.swift into it. Keeps the project structure self-
        // documenting (every app has a domain model home, even if empty)
        // without forcing adopters to pick SwiftData or Core Data upfront.
        if !config.hasSwiftData, !config.hasCoreData {
            try FileWriter.writeFile(
                at: "\(coreDir)/Models/.gitkeep",
                content: "",
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

        // Info.plist (feature-driven options for privacy strings, background modes, etc.)
        try FileWriter.writeFile(
            at: "\(name)/Info.plist",
            content: InfoPlistGenerator.generate(options: infoPlistOptions(for: config)),
            basePath: basePath
        )

        // ExportOptions.plist
        try FileWriter.writeFile(
            at: "ExportOptions.plist",
            content: ExportOptionsGenerator.generate(),
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
                content: CombineGenerator.generateDataPublisher(),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(coreDir)/Services/AsyncService.swift",
                content: CombineGenerator.generateAsyncService(),
                basePath: basePath
            )
        }

        // Mac Catalyst
        if config.hasMacCatalyst {
            try FileWriter.writeFile(
                at: "\(name)/MacCatalyst/MacWindowConfig.swift",
                content: MacCatalystGenerator.generateWindowConfig(),
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

        // Core Data
        if config.hasCoreData {
            let modelDir = "\(coreDir)/Models/\(name).xcdatamodeld"
            let modelOptions = CoreDataGenerator.Options(cloudKit: config.hasCloudKit)
            try FileWriter.writeFile(
                at: "\(modelDir)/\(name).xcdatamodel/contents",
                content: CoreDataGenerator.generateModelContents(options: modelOptions),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(modelDir)/.xccurrentversion",
                content: CoreDataGenerator.generateCurrentVersion(modelName: name),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(coreDir)/Persistence/\(name)CoreDataStack.swift",
                content: CoreDataGenerator.generateStack(config: config, options: modelOptions),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(testsDir)/Helpers/TestContext.swift",
                content: CoreDataGenerator.generateTestContext(config: config),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(testsDir)/Helpers/TestDataFactory.swift",
                content: CoreDataGenerator.generateTestDataFactory(config: config),
                basePath: basePath
            )
        }

        // Privacy manifest (app bundle)
        if config.hasPrivacyManifest {
            try FileWriter.writeFile(
                at: "\(resourcesDir)/PrivacyInfo.xcprivacy",
                content: PrivacyInfoGenerator.generate(role: .app),
                basePath: basePath
            )
        }

        // App icon alpha validation script
        if config.hasAppIconValidation {
            // executable: true matches the localization audit_strings.py
            // emission. Xcode's run-script build phase reads the file with
            // /bin/sh by default, so a non-executable bit isn't strictly fatal,
            // but adopters who run the script manually (`./Scripts/validate-app-icon.sh`)
            // need the +x bit and the workspace convention is to ship scripts
            // executable so they're ready to commit without `chmod +x`.
            try FileWriter.writeFile(
                at: "Scripts/validate-app-icon.sh",
                content: AppIconValidationGenerator.generate(
                    iconsetRelativePath: "\(resourcesDir)/Assets.xcassets/AppIcon.appiconset"
                ),
                basePath: basePath,
                executable: true
            )
        }

        // Widget extension
        if config.hasWidget {
            let widgetDir = "\(name)Widget"
            let appGroup = config.appGroupIdentifier
            try FileWriter.writeFile(
                at: "\(name)/\(name).entitlements",
                content: WidgetExtensionGenerator.generateAppEntitlements(appGroup: appGroup),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(widgetDir)/Info.plist",
                content: WidgetExtensionGenerator.generateInfoPlist(),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(widgetDir)/\(name)Widget.entitlements",
                content: WidgetExtensionGenerator.generateEntitlements(appGroup: appGroup),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(widgetDir)/\(name)WidgetBundle.swift",
                content: WidgetExtensionGenerator.generateBundle(appName: name),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(widgetDir)/\(name)Widget.swift",
                content: WidgetExtensionGenerator.generateWidget(appName: name, appGroup: appGroup),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(name)/Shared/AppGroup.swift",
                content: WidgetExtensionGenerator.generateAppGroupConstants(appGroup: appGroup),
                basePath: basePath
            )
            // Always emit the widget's PrivacyInfo, independent of the app's
            // hasPrivacyManifest feature flag. Every shipped bundle (app +
            // every .appex) needs its own manifest per Apple's privacy-report
            // generator at App Store upload — a widget without one ships a
            // half-declared app. The extension manifest is minimal (no
            // accessed-API types beyond what an empty widget uses), so
            // there's no reason to gate it behind the app-level flag.
            try FileWriter.writeFile(
                at: "\(widgetDir)/PrivacyInfo.xcprivacy",
                content: PrivacyInfoGenerator.generate(role: .extensionTarget),
                basePath: basePath
            )
        }

        // Localization
        if config.hasLocalization {
            try FileWriter.writeFile(
                at: "\(resourcesDir)/Localizable.xcstrings",
                content: LocalizationGenerator.generateStringCatalog(config: config),
                basePath: basePath
            )
            try FileWriter.writeFile(
                at: "\(coreDir)/L10n.swift",
                content: LocalizationGenerator.generateL10n(config: config),
                basePath: basePath
            )
            // Localization audit script — flags missing locales, placeholder
            // mismatches, and the silent-fail `String(localized:)` Swift
            // interpolation bug from workspace lessons.md. Wired into `make
            // check` automatically by `MakefileGenerator`.
            try FileWriter.writeFile(
                at: "Scripts/localization/audit_strings.py",
                content: LocalizationAuditGenerator.generate(appName: name),
                basePath: basePath,
                executable: true
            )
        }

        // Lottie
        if config.hasLottie {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Components/LottieHelper.swift",
                content: LottieGenerator.generateHelper(),
                basePath: basePath
            )
        }

        // Write the test target's source file BEFORE invoking xcodegen.
        // xcodegen's spec validator requires every target's source directory to
        // exist on disk; otherwise it fails with "Target has a missing source
        // directory" and writeProjectSystem can't delete project.yml. Without
        // this, every `xcodeproj`-mode app that doesn't enable swiftData /
        // coreData (the two paths that already wrote into testsDir earlier)
        // would surface a misleading "⚠ xcodegen failed" line.
        //
        // When a persistence layer is enabled, also emit one demo test that
        // exercises `TestContext` + `TestDataFactory` so:
        //   1. The scaffold's test count starts at 1, not 0 — adopters see a
        //      green test signal out of the box and know the test
        //      infrastructure works.
        //   2. The helper APIs are referenced (not dead code) until the
        //      adopter writes their first real test.
        // Adopters delete the demo and write real tests once they have a
        // real model.
        try FileWriter.writeFile(
            at: "\(testsDir)/\(name)Tests.swift",
            content: TestGenerator.generateAppTest(
                suiteName: config.name,
                withPersistenceDemo: config.hasSwiftData
            ),
            basePath: basePath
        )

        try writeProjectSystem(config: config, basePath: basePath)
        try writeInfraFiles(config: config, basePath: basePath)
        printNextSteps(config: config, basePath: basePath)
    }

    // MARK: - Info.plist Options

    /// Derives Info.plist options from the resolved feature set.
    /// Adopters customize usage strings before App Review; the placeholders
    /// here are honest stubs that will fail review intentionally if shipped
    /// unchanged.
    private static func infoPlistOptions(for config: AppConfig) -> InfoPlistGenerator.Options {
        var options = InfoPlistGenerator.Options()

        if config.hasCloudKitNotifications {
            options.backgroundModes.append("remote-notification")
        }

        if config.hasCloudKitSharing {
            options.cloudKitSharing = true
        }

        if config.hasDeepLinks {
            // Lowercase app name is a sensible default URL scheme — adopters
            // can rename in the generated Info.plist if it collides.
            options.urlSchemes.append(config.name.lowercased())
            // CFBundleURLName: Apple-recommended reverse-DNS identifier so
            // system tools can disambiguate URL handler identity if multiple
            // apps register the same scheme. Bundle ID is the natural choice.
            options.urlIdentifier = config.bundleID
        }

        // LSApplicationCategoryType lives in the Info.plist (vs. Xcode build
        // setting) so the file is fully self-describing — `plutil -p Info.plist`
        // shows every key, no need to cross-reference build settings to know
        // the App Store category. Required for Mac App Store distribution.
        // The applicationCategory field on AppConfig defaults to
        // `public.app-category.utilities` when macCatalyst is in platforms
        // (see NewAppCommand); other apps get the default too because Apple's
        // archive validator warns when this key is missing even for iOS-only.
        options.applicationCategoryType = config.applicationCategory ?? "public.app-category.utilities"

        return options
    }

    // MARK: - Project System

    private static func writeProjectSystem(config: AppConfig, basePath: String) throws {
        switch config.projectSystem {
        case .xcodeProj:
            // One-shot: write project.yml, run xcodegen, delete project.yml
            try FileWriter.writeFile(
                at: "project.yml",
                content: XcodeGenGenerator.generate(config: config, projectRoot: basePath),
                basePath: basePath
            )
            let success = XcodeGenRunner.generate(at: basePath)
            if success {
                try? FileManager.default.removeItem(
                    atPath: (basePath as NSString).appendingPathComponent("project.yml")
                )
            }
        case .xcodeGen:
            try FileWriter.writeFile(
                at: "project.yml",
                content: XcodeGenGenerator.generate(config: config, projectRoot: basePath),
                basePath: basePath
            )
        case .spm:
            try FileWriter.writeFile(
                at: "Package.swift",
                content: SPMAppGenerator.generate(config: config, projectRoot: basePath),
                basePath: basePath
            )
        }
    }

    // MARK: - Infrastructure Files

    private static func writeInfraFiles(config: AppConfig, basePath: String) throws {
        if config.hasFastlane {
            try FileWriter.writeFile(at: "Gemfile", content: FastlaneGenerator.generateGemfile(), basePath: basePath)
            try FileWriter.writeFile(at: "fastlane/Appfile", content: FastlaneGenerator.generateAppfile(config: config), basePath: basePath)
            try FileWriter.writeFile(at: "fastlane/Fastfile", content: FastlaneGenerator.generateFastfile(config: config), basePath: basePath)
        }

        if config.hasRSwift {
            try FileWriter.writeFile(at: "Mintfile", content: RSwiftGenerator.generateMintfile(), basePath: basePath)
        }

        try FileWriter.writeFile(
            at: ".gitignore",
            content: GitignoreGenerator.generate(options: GitignoreGenerator.Options(
                projectType: .app,
                hasRSwift: config.hasRSwift,
                hasFastlane: config.hasFastlane,
                appName: config.name
            )),
            basePath: basePath
        )

        try FileWriter.writeFile(at: "README.md", content: ReadmeGenerator.generateForApp(config: config), basePath: basePath)

        if config.hasDevTooling {
            // disableTestParallelism: pin Swift Testing's worker pool to 1.
            // Needed only when shared-singleton race risk is real — the
            // documented case is a persistence singleton (e.g. PetRepository.shared
            // backed by Core Data or SwiftData + NSPersistentCloudKitContainer)
            // racing across suites. Plain SwiftData (no CloudKit, no shared
            // repository) doesn't usually have this race because each test
            // gets an in-memory ModelContainer through `TestContext`. Gating
            // on `hasCloudKit` avoids the unnecessary serial-execution penalty
            // for the common SwiftData-without-sync case. Apps that introduce
            // their own singleton-on-persistence patterns later (Petfolio-style
            // shared repository) can re-enable serialization by wrapping
            // suites in a parent `.serialized` enum (see workspace lessons.md
            // Swift Testing section) without editing the Makefile.
            let needsTestSerialization = (config.hasCoreData || config.hasSwiftData) && config.hasCloudKit
            try FileWriter.writeToolingFiles(
                projectType: .app,
                appName: config.name,
                hasRSwift: config.hasRSwift,
                hasFastlane: config.hasFastlane,
                hasGitHooks: config.hasGitHooks,
                hasLocalization: config.hasLocalization,
                hasAppIconValidation: config.hasAppIconValidation,
                projectSystem: config.projectSystem,
                basePath: basePath,
                disableTestParallelism: needsTestSerialization
            )
        }

        if config.hasGitHooks {
            let hookOptions = GitHooksGenerator.Options(coreDataAudit: config.hasCoreDataAuditHook)
            try FileWriter.writeGitHooks(basePath: basePath, options: hookOptions)
        }

        try FileWriter.writeOptionalFiles(
            claudeMDContent: config.hasClaudeMD ? ClaudeMDGenerator.generateForApp(config: config) : nil,
            licenseAuthor: config.hasLicenseChangelog ? config.author : nil,
            licenseType: config.licenseType,
            basePath: basePath
        )
    }

    // MARK: - Console Output

    private static func printNextSteps(config: AppConfig, basePath: String) {
        print("\n  \(config.name) app created at \(basePath)")
        print()
        print("  Next steps:")
        if config.hasDevTooling {
            print("    brew bundle")
        }
        if config.hasGitHooks {
            print("    make setup-hooks")
        }
        // `SampleItem.swift` is only generated when SwiftData or Core Data is
        // enabled; mentioning it on a minimal scaffold tells adopters to edit
        // a file that doesn't exist.
        if config.hasSwiftData {
            print("    Replace Core/Models/SampleItem.swift with your domain models and update AppDelegate.swift SwiftData schema")
        } else if config.hasCoreData {
            print("    Replace Core/Models/SampleItem.swift with your domain models")
        }
        print("    Build feature view controllers in Features/")
    }
}
