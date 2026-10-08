import ArgumentParser
import Foundation

enum AppProjectGenerator {
    static func generate(config: AppConfig, outputDir: String? = nil) throws {
        // Every entry point rejects SPM for apps first; this keeps a direct
        // caller from getting a project.yml it didn't ask for.
        guard config.projectSystem.isSupportedForApps else {
            throw ValidationError(
                "projectSystem '\(config.projectSystem.rawValue.lowercased())' is not supported for apps: \(ProjectSystem.unsupportedForAppsReason)"
            )
        }
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

        // Dark Mode (standalone, without LumiKit)
        if config.hasDarkMode, !config.hasLumiKit {
            try FileWriter.writeFile(
                at: "\(sharedDir)/Design/AppTheme.swift",
                content: DarkModeGenerator.generate(config: config),
                basePath: basePath
            )
        }

        // Combine / Async patterns. Only emits the Task-cancellation reference
        // template; the historical `DataPublisher.swift` sample singleton was
        // removed because adopters universally deleted it on first commit
        // (see CombineGenerator's doc comment).
        if config.hasCombine {
            try FileWriter.writeFile(
                at: "\(coreDir)/Services/AsyncService.swift",
                content: CombineGenerator.generateAsyncService(),
                basePath: basePath
            )
        }

        // Mac Catalyst. A LumiKit app configures its window with
        // `LMKScene.configureMacWindow` in SceneDelegate instead.
        if config.hasMacCatalyst, !config.hasLumiKit {
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
            let modelOptions = CoreDataGenerator.Options(
                cloudKit: config.hasCloudKit,
                sharing: config.hasCloudKitSharing
            )
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

        // Privacy manifest (app bundle). Declares what the generated code
        // and statically linked LumiKit reach (see `appCategories`); a plain
        // scaffold reaches no required-reason API and stays empty.
        if config.hasPrivacyManifest {
            let apiCategories = PrivacyInfoGenerator.appCategories(
                hasCloudKit: config.hasCloudKit,
                hasLumiKit: config.hasLumiKit
            )
            try FileWriter.writeFile(
                at: "\(resourcesDir)/PrivacyInfo.xcprivacy",
                content: PrivacyInfoGenerator.generate(role: .app, categories: apiCategories),
                basePath: basePath
            )
        }

        // App icon alpha validation script
        if config.hasAppIconValidation {
            // executable: true matches the localization audit_strings.py
            // emission. Xcode's run-script build phase reads the file with
            // /bin/sh by default, so a non-executable bit isn't strictly fatal,
            // but adopters who run the script manually (`./Scripts/validate-app-icon.sh`)
            // need the +x bit, so scripts ship executable and are ready to
            // commit without `chmod +x`.
            try FileWriter.writeFile(
                at: "Scripts/validate-app-icon.sh",
                content: AppIconValidationGenerator.generate(
                    iconsetRelativePath: "\(resourcesDir)/Assets.xcassets/AppIcon.appiconset"
                ),
                basePath: basePath,
                executable: true
            )
        }

        // App target entitlements. Composed from the capability features that
        // actually need entitlement keys: App Group (widget/extension state
        // sharing) and CloudKit (iCloud container + service + APNs). Gated on
        // the union, not on `hasWidget` alone — a CloudKit app without a widget
        // still needs the iCloud + aps-environment keys, and without them
        // NSPersistentCloudKitContainer silently falls back to a local store
        // and registerForRemoteNotifications() fails at runtime.
        let appGroup = config.hasWidget ? config.appGroupIdentifier : nil
        let cloudKitContainer = config.hasCloudKit ? "iCloud.\(config.bundleID)" : nil
        let apsEnvironment = config.hasCloudKitNotifications ? "development" : nil
        if config.hasWidget || config.hasCloudKit {
            try FileWriter.writeFile(
                at: EntitlementsGenerator.appPath(appName: name),
                content: EntitlementsGenerator.appEntitlements(
                    appGroup: appGroup,
                    cloudKitContainer: cloudKitContainer,
                    apsEnvironment: apsEnvironment
                ),
                basePath: basePath
            )
        }

        // Mac Catalyst entitlements: the same capabilities plus App Sandbox
        // (required on the Mac App Store) and outgoing network access.
        // Written for every Catalyst app, capabilities or not.
        if config.hasMacCatalyst {
            try FileWriter.writeFile(
                at: EntitlementsGenerator.macCatalystPath(appName: name),
                content: EntitlementsGenerator.macCatalystEntitlements(
                    appGroup: appGroup,
                    cloudKitContainer: cloudKitContainer,
                    apsEnvironment: apsEnvironment
                ),
                basePath: basePath
            )
        }

        // Widget extension
        if config.hasWidget {
            for file in WidgetExtensionGenerator.files(appName: name, appGroup: config.appGroupIdentifier) {
                try FileWriter.writeFile(at: file.path, content: file.content, basePath: basePath)
            }
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
            // interpolation bug (a literal `\(...)` in a catalog key never
            // matches at lookup). Wired into `make check` automatically by
            // `MakefileGenerator`.
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
                persistence: config.hasSwiftData ? .swiftData : (config.hasCoreData ? .coreData : .none),
                serialized: TestGenerator.appTestsRunSerially(config: config)
            ),
            basePath: basePath
        )

        let hasProject = try writeProjectSystem(config: config, basePath: basePath)
        try writeInfraFiles(config: config, basePath: basePath)
        guard hasProject else {
            // The warning above carries xcodegen's own output. Every other
            // file is on disk, so keep it and say how to finish instead of
            // reporting success.
            throw IncompleteGenerationError(description: """
            xcodegen could not create \(name).xcodeproj. The rest of the app is at \(basePath), \
            with project.yml kept: fix the problem above, run `xcodegen generate` there, then delete project.yml. \
            Any requested git init, package resolve, or open was skipped.
            """)
        }
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

    /// Writes the project system. `.xcodeGen` keeps project.yml; `.xcodeProj`
    /// runs xcodegen once and deletes it. Returns false when `.xcodeProj` mode
    /// could not run xcodegen, leaving project.yml in place of the Xcode project.
    private static func writeProjectSystem(config: AppConfig, basePath: String) throws -> Bool {
        try FileWriter.writeFile(
            at: "project.yml",
            content: XcodeGenGenerator.generate(config: config, projectRoot: basePath),
            basePath: basePath
        )
        guard config.projectSystem == .xcodeProj else { return true }
        guard XcodeGenRunner.generate(at: basePath) else { return false }
        try? FileManager.default.removeItem(
            atPath: (basePath as NSString).appendingPathComponent("project.yml")
        )
        return true
    }

    // MARK: - Infrastructure Files

    private static func writeInfraFiles(config: AppConfig, basePath: String) throws {
        if config.hasFastlane {
            try FileWriter.writeFile(at: "Gemfile", content: FastlaneGenerator.generateGemfile(), basePath: basePath)
            try FileWriter.writeFile(at: "fastlane/Appfile", content: FastlaneGenerator.generateAppfile(config: config), basePath: basePath)
            try FileWriter.writeFile(at: "fastlane/Fastfile", content: FastlaneGenerator.generateFastfile(config: config), basePath: basePath)
            // The Fastfile's `beta` lane exports with it. The Makefile's
            // `release` doesn't: it archives and opens Xcode's Organizer.
            try FileWriter.writeFile(at: "ExportOptions.plist", content: ExportOptionsGenerator.generate(), basePath: basePath)
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
            // disableTestParallelism: run the tests one at a time, by the same
            // rule as the test file's `.serialized` parent suite (see
            // `TestGenerator.appTestsRunSerially`). Plain SwiftData keeps the
            // parallel run: each test gets its own in-memory container.
            let needsTestSerialization = TestGenerator.appTestsRunSerially(config: config)
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
                disableTestParallelism: needsTestSerialization,
                hasMacCatalyst: config.hasMacCatalyst,
                hasWidget: config.hasWidget
            )
        }

        if config.hasGitHooks {
            try FileWriter.writeGitHooks(basePath: basePath, options: hookOptions(for: config))
        }

        try FileWriter.writeOptionalFiles(
            claudeMDContent: config.hasClaudeMD ? ClaudeMDGenerator.generateForApp(config: config) : nil,
            licenseAuthor: config.hasLicenseChangelog ? config.author : nil,
            licenseType: config.licenseType,
            projectName: config.name,
            basePath: basePath
        )
    }

    /// The schema-audit reminder matches the persistence layer: staged
    /// `.xcdatamodel` changes for Core Data, staged `Core/Models/*.swift` or
    /// `@Model` edits for SwiftData. An explicit `coreDataAuditHook` with
    /// neither layer keeps the Core Data reminder.
    static func hookOptions(for config: AppConfig) -> GitHooksGenerator.Options {
        guard config.hasCoreDataAuditHook else { return .basic }
        return GitHooksGenerator.Options(
            coreDataAudit: config.hasCoreData || !config.hasSwiftData,
            swiftDataAudit: config.hasSwiftData
        )
    }

    // MARK: - Next Steps

    /// The app's own next steps, printed by `NewCommandRunner` after git
    /// init (which adds the tooling and hooks steps before these).
    static func nextSteps(config: AppConfig) -> [String] {
        var steps: [String] = []
        // The SampleItem placeholder differs by persistence layer: SwiftData
        // writes a `SampleItem.swift` @Model file, while Core Data seeds a
        // `SampleItem` entity inside the `.xcdatamodeld` (codegen=class, no
        // Swift file). A minimal scaffold with neither gets no line at all.
        if config.hasSwiftData {
            steps.append("Replace SampleItem in Core/Models/SampleItem.swift with your domain models, and register each @Model type in AppSchema.models there")
        } else if config.hasCoreData {
            steps.append("Replace the SampleItem entity in Core/Models/\(config.name).xcdatamodeld with your domain model entities")
        }
        steps.append("Build feature view controllers in Features/")
        return steps
    }
}
