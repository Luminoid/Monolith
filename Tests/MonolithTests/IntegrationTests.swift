import Foundation
import Testing
@testable import MonolithLib

@Suite("Integration", .serialized)
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

    @Test("CLI project generates all expected files")
    func cliProjectFiles() throws {
        try withTempDir(prefix: "monolith-test-cli") { tempDir in
            let config = CLIConfig(
                name: "TestCLI",
                includeArgumentParser: true,
                features: [.devTooling, .claudeMD, .licenseChangelog, .strictConcurrency],
                author: "Test"
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
        }
    }

    // MARK: - Package Generation

    @Test("Package project generates all expected files")
    func packageProjectFiles() throws {
        try withTempDir(prefix: "monolith-test-pkg") { tempDir in
            let config = PackageConfig(
                name: "TestLib",
                platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                targets: [
                    TargetDefinition(name: "TestLibCore", dependencies: []),
                    TargetDefinition(name: "TestLibUI", dependencies: ["TestLibCore"]),
                ],
                features: [.devTooling],
                mainActorTargets: [],
                author: "Test"
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
        }
    }

    // MARK: - App Generation

    @Test("App project generates core files")
    func appProjectCoreFiles() throws {
        try withTempDir(prefix: "monolith-test-app") { tempDir in
            let config = AppConfig(
                name: "TestApp",
                bundleID: "com.test.app",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .spm,
                tabs: [],
                primaryColor: "#007AFF",
                features: [],
                author: "Test"
            )
            try AppProjectGenerator.generate(config: config)

            let basePath = "\(tempDir)/TestApp"
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/App/AppDelegate.swift"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/App/SceneDelegate.swift"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Core/AppConstants.swift"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Shared/ViewController.swift"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/TestApp/Info.plist"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/ExportOptions.plist"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/Package.swift"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/.gitignore"))
            #expect(FileManager.default.fileExists(atPath: "\(basePath)/README.md"))
        }
    }

    @Test("App with all features generates expected files")
    func appAllFeatures() throws {
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
                features: [.swiftData, .darkMode, .combine, .localization, .devTooling, .claudeMD, .licenseChangelog],
                author: "Test"
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

    // MARK: - Feature Combinations

    @Test("all feature combinations don't crash")
    func featureCombinations() throws {
        try withTempDir(prefix: "monolith-test-combos") { _ in
            let combos: [Set<AppFeature>] = [
                [],
                [.swiftData],
                [.darkMode],
                [.combine],
                [.swiftData, .darkMode, .combine],
                [.localization],
                [.devTooling, .claudeMD, .licenseChangelog],
            ]
            for (index, features) in combos.enumerated() {
                let config = AppConfig(
                    name: "Combo\(index)",
                    bundleID: "com.test.combo\(index)",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .spm,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: features,
                    author: "Test"
                )
                try AppProjectGenerator.generate(config: config)
            }
            #expect(true)
        }
    }

    // MARK: - All Ecosystem Colors

    @Test("all ecosystem primary colors generate valid themes")
    func ecosystemColors() {
        let colors = ["#4CAF7D", "#D4875A", "#4A7FE0", "#5C6BC0", "#007AFF"]
        for hex in colors {
            let config = AppConfig(
                name: "ColorTest",
                bundleID: "com.test.color",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .spm,
                tabs: [],
                primaryColor: hex,
                features: [.darkMode],
                author: "Test"
            )
            let output = DarkModeGenerator.generate(config: config)
            #expect(output.contains("AppTheme"), "Failed for \(hex)")
            #expect(output.contains("UIColor"), "Failed for \(hex)")
            #expect(!output.contains("systemBlue"), "Fallback triggered for \(hex)")
        }
    }
}
