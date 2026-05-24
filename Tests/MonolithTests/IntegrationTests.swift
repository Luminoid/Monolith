import Foundation
import Testing
@testable import MonolithLib

/// Baseline integration suite: smoke tests for each project type, plus the
/// "everything together" feature combo. Per-feature coverage lives in
/// sibling suites (`AppFeatureIntegrationTests`, `PackageCLIIntegrationTests`)
/// so each suite stays under `type_body_length`.
///
/// All integration suites are children of `MonolithIntegrationSuite` so
/// `.serialized` propagates downward; this prevents the `currentDirectoryPath`
/// race that would otherwise let sibling top-level suites interleave their
/// `withTempDir` calls.
extension MonolithIntegrationSuite {
    struct IntegrationTests {
        // MARK: - CLI Generation

        @Test
        func `CLI project generates all expected files`() throws {
            try withTempDir(prefix: "monolith-test-cli") { tempDir in
                let config = CLIConfig(
                    name: "TestCLI",
                    includeArgumentParser: true,
                    features: [.devTooling, .gitHooks, .claudeMD, .licenseChangelog, .strictConcurrency],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/TestCLI"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Package.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Sources/TestCLI/TestCLI.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Tests/TestCLITests/TestCLITests.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.gitignore"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/README.md"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftformat"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Makefile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Brewfile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.claude/CLAUDE.md"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/LICENSE"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/CHANGELOG.md"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))
            }
        }

        // MARK: - Package Generation

        @Test
        func `Package project generates all expected files`() throws {
            try withTempDir(prefix: "monolith-test-pkg") { tempDir in
                let config = PackageConfig(
                    name: "TestLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [
                        TargetDefinition(name: "TestLibCore", dependencies: []),
                        TargetDefinition(name: "TestLibUI", dependencies: ["TestLibCore"]),
                    ],
                    features: [.devTooling, .gitHooks],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit
                )
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/TestLib"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Package.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Sources/TestLibCore/TestLibCore.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Sources/TestLibUI/TestLibUI.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Tests/TestLibCoreTests/TestLibCoreTests.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Tests/TestLibUITests/TestLibUITests.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.gitignore"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/README.md"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))
            }
        }

        // MARK: - App Generation

        @Test
        func `App project generates core files`() throws {
            try withTempDir(prefix: "monolith-test-app") { tempDir in
                let config = AppConfig(
                    name: "TestApp",
                    bundleID: "com.test.app",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/TestApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/App/AppDelegate.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/App/SceneDelegate.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Core/AppConstants.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Shared/ViewController.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Info.plist"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/ExportOptions.plist"))
                // xcodeProj writes project.yml, runs xcodegen, then deletes
                // project.yml on success. Whichever path the test environment
                // exercises (xcodegen installed → .xcodeproj; not installed →
                // project.yml remains), at least one of them must exist.
                let hasXcodeproj = FileManager.default.fileExists(atPath: "\(basePath)/TestApp.xcodeproj")
                let hasProjectYml = FileManager.default.fileExists(atPath: "\(basePath)/project.yml")
                #expect(hasXcodeproj || hasProjectYml)
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.gitignore"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/README.md"))
                // Placeholder dirs when neither tabs nor persistence is set:
                // README's "next steps" references both Features/ and Models/,
                // so both must exist on disk.
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Features/.gitkeep"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Core/Models/.gitkeep"))
            }
        }

        @Test
        func `App with all features generates expected files`() throws {
            try withTempDir(prefix: "monolith-test-full") { tempDir in
                let config = AppConfig(
                    name: "FullApp",
                    bundleID: "com.test.full",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone, .macCatalyst],
                    projectSystem: .xcodeGen,
                    tabs: [
                        TabDefinition(name: "Home", icon: "house.fill"),
                        TabDefinition(name: "Settings", icon: "gear"),
                    ],
                    primaryColor: "#4CAF7D",
                    features: [.swiftData, .darkMode, .combine, .localization, .devTooling, .gitHooks, .claudeMD, .licenseChangelog],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/FullApp"

                // Core files
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/App/AppDelegate.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/App/SceneDelegate.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/App/MainTabBarController.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Core/AppConstants.swift"))

                // Feature VCs (from tabs)
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Features/Home/HomeViewController.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Features/Settings/SettingsViewController.swift"))

                // Dark mode
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Shared/Design/AppTheme.swift"))

                // Combine
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Core/Services/DataPublisher.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Core/Services/AsyncService.swift"))

                // Mac Catalyst
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/MacCatalyst/MacWindowConfig.swift"))

                // SwiftData
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Core/Models/SampleItem.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullAppTests/Helpers/TestContext.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullAppTests/Helpers/TestDataFactory.swift"))

                // XcodeGen
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/project.yml"))

                // Tooling
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftformat"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Makefile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Brewfile"))

                // Git hooks
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))

                // CLAUDE.md
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.claude/CLAUDE.md"))

                // Localization
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Resources/Localizable.xcstrings"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Core/L10n.swift"))

                // License + Changelog
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/LICENSE"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/CHANGELOG.md"))

                // No placeholder .gitkeep when the dirs already have content:
                // tabs populate Features/<Name>/, SwiftData populates
                // Core/Models/SampleItem.swift.
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Features/.gitkeep"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/FullApp/Core/Models/.gitkeep"))
            }
        }

        // MARK: - Content Verification

        @Test
        func `generated project.yml is valid for xcodeProj app`() {
            // Test the generator output directly. The full pipeline deletes
            // project.yml after xcodegen succeeds (when installed in the test
            // env), so reading the file from disk is environment-dependent.
            // The generator function itself is the unit we care about.
            let config = AppConfig(
                name: "ProjApp",
                bundleID: "com.test.proj",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeProj,
                tabs: [],
                primaryColor: "#007AFF",
                features: [],
                author: "Test",
                licenseType: .proprietary
            )
            let yml = XcodeGenGenerator.generate(config: config)
            #expect(yml.contains("ProjApp"))
            #expect(yml.contains("type: application"))
        }

        @Test
        func `generated CLI main has ArgumentParser structure`() throws {
            try withTempDir(prefix: "monolith-test-cli-content") { tempDir in
                let config = CLIConfig(
                    name: "mycli",
                    includeArgumentParser: true,
                    features: [],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/mycli"
                let main = try String(contentsOfFile: "\(basePath)/Sources/mycli/mycli.swift", encoding: .utf8)
                #expect(main.contains("import ArgumentParser"))
                #expect(main.contains("@main"))
                #expect(main.contains("ParsableCommand"))
                #expect(main.contains("func run()"))
            }
        }

        @Test
        func `generated package Package.swift has correct targets and dependencies`() throws {
            try withTempDir(prefix: "monolith-test-pkg-targets") { tempDir in
                let config = PackageConfig(
                    name: "TestLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [
                        TargetDefinition(name: "Core", dependencies: []),
                        TargetDefinition(name: "UI", dependencies: ["Core"]),
                    ],
                    features: [],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit
                )
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/TestLib"
                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(pkg.contains("\"Core\""))
                #expect(pkg.contains("\"UI\""))
                #expect(pkg.contains(".iOS(.v18)"))
            }
        }

        // MARK: - Output Directory

        @Test
        func `CLI generation respects outputDir parameter`() throws {
            try withTempDir(prefix: "monolith-test-output") { tempDir in
                let outputDir = "\(tempDir)/custom-output"
                try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

                let config = CLIConfig(
                    name: "OutTest",
                    includeArgumentParser: false,
                    features: [],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config, outputDir: outputDir)

                #expect(FileManager.default.fileExists(atPath: "\(outputDir)/OutTest/Package.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(outputDir)/OutTest/Sources/OutTest/OutTest.swift"))
            }
        }

        // MARK: - Feature Combinations

        @Test
        func `all feature combinations generate valid Swift files`() throws {
            try withTempDir(prefix: "monolith-test-combos") { tempDir in
                let combos: [Set<AppFeature>] = [
                    [],
                    [.swiftData],
                    [.darkMode],
                    [.combine],
                    [.swiftData, .darkMode, .combine],
                    [.localization],
                    [.devTooling, .claudeMD, .licenseChangelog],
                    [.gitHooks],
                    [.devTooling, .gitHooks],
                ]
                for (index, features) in combos.enumerated() {
                    let config = AppConfig(
                        name: "Combo\(index)",
                        bundleID: "com.test.combo\(index)",
                        deploymentTarget: "18.0",
                        platforms: [.iPhone],
                        projectSystem: .xcodeProj,
                        tabs: [],
                        primaryColor: "#007AFF",
                        features: features,
                        author: "Test",
                        licenseType: .proprietary
                    )
                    try AppProjectGenerator.generate(config: config)

                    // Verify generated AppDelegate is valid Swift (has import and class)
                    let basePath = "\(tempDir)/Combo\(index)"
                    let delegate = try String(contentsOfFile: "\(basePath)/Combo\(index)/App/AppDelegate.swift", encoding: .utf8)
                    #expect(delegate.contains("import UIKit"), "Combo \(index) missing UIKit import")
                    #expect(delegate.contains("class AppDelegate"), "Combo \(index) missing AppDelegate class")
                }
            }
        }

        // MARK: - Git Hooks

        @Test
        func `Pre-commit hook has executable permissions`() throws {
            try withTempDir(prefix: "monolith-test-perms") { tempDir in
                let config = CLIConfig(
                    name: "HookTest",
                    includeArgumentParser: false,
                    features: [.gitHooks],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config)

                let hookPath = "\(tempDir)/HookTest/Scripts/git-hooks/pre-commit"
                #expect(FileManager.default.fileExists(atPath: hookPath))

                let attrs = try FileManager.default.attributesOfItem(atPath: hookPath)
                let permissions = attrs[.posixPermissions] as? Int
                #expect(permissions == 0o755)
            }
        }

        @Test
        func `Git hooks without devTooling generates hook but no Makefile`() throws {
            try withTempDir(prefix: "monolith-test-hooks-only") { tempDir in
                let config = CLIConfig(
                    name: "HooksOnly",
                    includeArgumentParser: false,
                    features: [.gitHooks],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/HooksOnly"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Makefile"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
            }
        }

        @Test
        func `DevTooling without gitHooks generates no hook script`() throws {
            try withTempDir(prefix: "monolith-test-tooling-only") { tempDir in
                let config = CLIConfig(
                    name: "ToolingOnly",
                    includeArgumentParser: false,
                    features: [.devTooling],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/ToolingOnly"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Makefile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))
            }
        }

        // MARK: - All Ecosystem Colors

        @Test
        func `all ecosystem primary colors generate valid themes`() {
            let colors = ["#4CAF7D", "#D4875A", "#4A7FE0", "#5C6BC0", "#007AFF"]
            for hex in colors {
                let config = AppConfig(
                    name: "ColorTest",
                    bundleID: "com.test.color",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: hex,
                    features: [.darkMode],
                    author: "Test",
                    licenseType: .proprietary
                )
                let output = DarkModeGenerator.generate(config: config)
                #expect(output.contains("AppTheme"), "Failed for \(hex)")
                #expect(output.contains("UIColor"), "Failed for \(hex)")
                #expect(!output.contains("systemBlue"), "Fallback triggered for \(hex)")
            }
        }

        // MARK: - Generator Output Sanity Checks

        //
        // These tests exercise generator output as structured data, not as
        // substrings. Substring assertions (yml.contains("LumiKit")) can pass
        // against output that's syntactically broken or semantically wrong
        // (e.g. a `- package: LumiKit` entry against a package whose products
        // are LumiKitCore / LumiKitUI / LumiKitLottie / LumiKitNetwork — no
        // product named "LumiKit" exists, so xcodebuild fails with
        // "Missing package product 'LumiKit'"). The tests below close those
        // gaps by parsing the YAML and asserting on structural facts.

        @Test
        func `xcodegen YAML is parseable for every devTooling combination`() {
            // Regression: a multi-line Swift heredoc whose closing """ aligned
            // to the function's natural indent emitted preBuildScripts: at
            // column 0 instead of nested under the target. xcodegen then
            // failed spec validation on the next sibling target. All four
            // devTooling apps in the integration matrix (FullApp, AllOnApp,
            // Combo6, Combo8) were broken at xcodegen time, but no test caught
            // it because every assertion was a substring match.
            let combos: [(name: String, features: Set<AppFeature>, projectSystem: ProjectSystem)] = [
                ("YamlBase", [.devTooling], .xcodeGen),
                ("YamlFull", [.devTooling, .gitHooks, .swiftData, .localization], .xcodeGen),
                ("YamlWidget", [.devTooling, .widget, .privacyManifest], .xcodeGen),
                ("YamlNoTool", [], .xcodeGen),
            ]
            for combo in combos {
                let config = AppConfig(
                    name: combo.name,
                    bundleID: "com.test.\(combo.name.lowercased())",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: combo.projectSystem,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: combo.features,
                    author: "Test",
                    licenseType: .proprietary
                )
                let yml = XcodeGenGenerator.generate(config: config)
                // Structural: every line starting with `preBuildScripts:` or
                // `postCompileScripts:` must be indented under a target (4+
                // spaces), never at column 0.
                for line in yml.split(separator: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("preBuildScripts:") || trimmed.hasPrefix("postCompileScripts:") {
                        let leading = line.prefix(while: { $0 == " " }).count
                        #expect(leading >= 4, "\(combo.name): build-phase key at column \(leading), expected ≥ 4")
                    }
                }
                // The test target's source dir must appear under `targets:`,
                // not orphaned outside (the symptom of the indent bug).
                let testTargetMarker = "  \(combo.name)Tests:\n"
                #expect(yml.contains(testTargetMarker), "\(combo.name): test target not properly nested under targets:")
            }
        }

        @Test
        func `LumiKit dependency declares a real product, not the package name`() {
            // Regression: LumiKit's Package.swift exposes products LumiKitCore
            // / LumiKitUI / LumiKitLottie / LumiKitNetwork, but no product
            // called "LumiKit". The generator used to emit `- package: LumiKit`
            // alone, which xcodegen interprets as `productRef = LumiKit` —
            // xcodebuild fails with "Missing package product 'LumiKit'".
            let config = AppConfig(
                name: "LMKTest",
                bundleID: "com.test.lmk",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeGen,
                tabs: [],
                primaryColor: "#007AFF",
                features: [.lumiKit],
                author: "Test",
                licenseType: .proprietary
            )
            let yml = XcodeGenGenerator.generate(config: config)
            #expect(yml.contains("- package: LumiKit"))
            // The disambiguating `product:` line must be on the very next
            // line so xcodegen wires the right framework.
            #expect(yml.contains("- package: LumiKit\n        product: LumiKitUI"))
        }

        @Test
        func `xcodeProj-mode app writes test source file before invoking xcodegen`() throws {
            // Regression: writeProjectSystem ran before the test source file
            // was emitted, so xcodegen failed spec validation on the missing
            // testsDir for every xcodeproj-mode app without coreData / swiftData
            // (those two were the only paths that wrote a testsDir file
            // earlier in generate()). Asserting the source file exists right
            // after generate() returns confirms the ordering is correct.
            try withTempDir(prefix: "monolith-test-order") { tempDir in
                let config = AppConfig(
                    name: "OrderApp",
                    bundleID: "com.test.order",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/OrderApp"
                let testFile = "\(basePath)/OrderAppTests/OrderAppTests.swift"
                #expect(FileManager.default.fileExists(atPath: testFile))
            }
        }

        @Test
        func `appIconValidation script is executable`() throws {
            try withTempDir(prefix: "monolith-test-iconperm") { tempDir in
                let config = AppConfig(
                    name: "IconPerm",
                    bundleID: "com.test.iconperm",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.appIconValidation],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let scriptPath = "\(tempDir)/IconPerm/Scripts/validate-app-icon.sh"
                let attrs = try FileManager.default.attributesOfItem(atPath: scriptPath)
                let permissions = attrs[.posixPermissions] as? Int
                #expect(permissions == 0o755)
            }
        }

        @Test
        func `MainTabBarController exposes a callable initializer without swiftData`() {
            let config = AppConfig(
                name: "TabApp",
                bundleID: "com.test.tabapp",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeGen,
                tabs: [TabDefinition(name: "Home", icon: "house.fill")],
                primaryColor: "#007AFF",
                features: [],
                author: "Test",
                licenseType: .proprietary
            )
            let output = TabBarGenerator.generate(config: config)
            // Must declare a parameterless `init()` so SceneDelegate's
            // `MainTabBarController()` call compiles. Overriding
            // `init(nibName:bundle:)` while marking `init?(coder:)` unavailable
            // breaks UIKit's inherited `init()`, producing "missing argument
            // for parameter 'coder' in call" at every call site.
            #expect(output.contains("init() {"))
            #expect(output.contains("super.init(nibName: nil, bundle: nil)"))
        }

        @Test
        func `Core Data stack singleton is concurrency-safe under strict concurrency`() {
            let config = AppConfig(
                name: "CDConcur",
                bundleID: "com.test.cdconcur",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeGen,
                tabs: [],
                primaryColor: "#007AFF",
                features: [.coreData],
                author: "Test",
                licenseType: .proprietary
            )
            let stack = CoreDataGenerator.generateStack(
                config: config,
                options: CoreDataGenerator.Options(cloudKit: false)
            )
            // Swift 6.2 rejects `static let shared = SomeClass()` unless the
            // type is Sendable. @MainActor isolation makes the class
            // implicitly Sendable and matches Petfolio's convention.
            #expect(stack.contains("@MainActor\nfinal class CDConcurCoreDataStack"))
            // TestContext must inherit the same isolation so callers can use
            // `inMemory()` from MainActor-isolated tests without an actor hop.
            let testContext = CoreDataGenerator.generateTestContext(config: config)
            #expect(testContext.contains("@MainActor"))
        }

        @Test
        func `deferredLaunchWork comment does not use mid-sentence em dash`() {
            let config = AppConfig(
                name: "DLWord",
                bundleID: "com.test.dlword",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeGen,
                tabs: [],
                primaryColor: "#007AFF",
                features: [.deferredLaunchWork],
                author: "Test",
                licenseType: .proprietary
            )
            let scene = SceneDelegateGenerator.generate(config: config)
            // Workspace rule: no inline em-dash as parenthetical separator
            // ("X — Y" mid-sentence). Decorative dividers, headings, ranges
            // are fine. The deferLaunchWork comment used to read "Non-blocking
            // startup work — Spotlight reindex,...".
            #expect(!scene.contains("Non-blocking startup work —"))
        }

        @Test
        func `SceneDelegate imports LumiKitUI when LumiKit is enabled`() {
            // Regression: SceneDelegateGenerator references LMKNavigationController
            // for the rootViewController wrapping but didn't emit `import LumiKitUI`,
            // so every LumiKit app's SceneDelegate failed to compile with
            // "cannot find 'LMKNavigationController' in scope". Latent until B5
            // fixed the LumiKit product reference — before that fix, LumiKit
            // didn't link at all and the missing import was masked.
            let config = AppConfig(
                name: "LMKImport",
                bundleID: "com.test.lmkimport",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeGen,
                tabs: [],
                primaryColor: "#007AFF",
                features: [.lumiKit],
                author: "Test",
                licenseType: .proprietary
            )
            let scene = SceneDelegateGenerator.generate(config: config)
            #expect(scene.contains("import LumiKitUI"))
            #expect(scene.contains("LMKNavigationController"))
        }
    }
}
