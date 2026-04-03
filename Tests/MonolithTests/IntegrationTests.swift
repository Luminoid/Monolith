import Foundation
import Testing
@testable import MonolithLib

@Suite(.serialized)
struct IntegrationTests {
    /// Run a generator inside a temp dir (changing cwd), then restore.
    /// The body receives the real (symlink-resolved) temp dir path from `currentDirectoryPath`.
    private func withTempDir(prefix: String, body: (String) throws -> Void) throws {
        let raw = NSTemporaryDirectory() + "\(prefix)-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(raw)
        // currentDirectoryPath resolves symlinks, giving us /private/var/... on macOS
        let resolved = FileManager.default.currentDirectoryPath
        defer {
            FileManager.default.changeCurrentDirectoryPath(originalDir)
            try? FileManager.default.removeItem(atPath: raw)
        }
        try body(resolved)
    }

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
            // xcodeProj writes project.yml (remains if xcodegen not available in test env)
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/project.yml"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/.gitignore"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/README.md"))
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
        }
    }

    // MARK: - Content Verification

    @Test
    func `generated AppDelegate contains expected Swift code`() throws {
        try withTempDir(prefix: "monolith-test-content") { tempDir in
            let config = AppConfig(
                name: "ContentApp",
                bundleID: "com.test.content",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeProj,
                tabs: [],
                primaryColor: "#007AFF",
                features: [.swiftData],
                author: "Test",
                licenseType: .proprietary
            )
            try AppProjectGenerator.generate(config: config)

            let basePath = "\(tempDir)/ContentApp"
            let delegate = try String(contentsOfFile: "\(basePath)/ContentApp/App/AppDelegate.swift", encoding: .utf8)
            #expect(delegate.contains("import UIKit"))
            #expect(delegate.contains("import SwiftData"))
            #expect(delegate.contains("@main"))
            #expect(delegate.contains("class AppDelegate"))
            #expect(delegate.contains("didFinishLaunchingWithOptions"))
            #expect(delegate.contains("ModelContainer"))
        }
    }

    @Test
    func `generated project.yml is valid for xcodeProj app`() throws {
        try withTempDir(prefix: "monolith-test-proj-content") { tempDir in
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
            try AppProjectGenerator.generate(config: config)

            let basePath = "\(tempDir)/ProjApp"
            let yml = try String(contentsOfFile: "\(basePath)/project.yml", encoding: .utf8)
            #expect(yml.contains("ProjApp"))
            #expect(yml.contains("type: application"))
        }
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
}
