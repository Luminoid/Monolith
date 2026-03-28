import Foundation
import Testing
@testable import MonolithLib

struct ClaudeMDGeneratorTests {
    // MARK: - App

    @Test
    func `app CLAUDE.md has app name and tech stack`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [.swiftData, .lumiKit],
            author: "Test"
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("# MyApp"))
        #expect(output.contains("SwiftData"))
        #expect(output.contains("LumiKit"))
        #expect(output.contains("make build"))
    }

    @Test
    func `app CLAUDE.md shows tab navigation when tabs present`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [TabDefinition(name: "Home", icon: "house")],
            primaryColor: "#007AFF",
            features: [],
            author: "Test"
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("UITabBarController"))
    }

    @Test
    func `app CLAUDE.md shows xcodebuild for XcodeGen`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test"
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("xcodegen generate"))
        #expect(output.contains("make build"))
    }

    // MARK: - Package

    @Test
    func `package CLAUDE.md has target table`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test"
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("# MyLib"))
        #expect(output.contains("| Core |"))
        #expect(output.contains("| UI |"))
        #expect(output.contains("xcodebuild"))
        #expect(output.contains("-scheme MyLib-Package"))
    }

    // MARK: - CLI

    @Test
    func `CLI CLAUDE.md has run command`() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: true,
            features: [],
            author: "Test"
        )
        let output = ClaudeMDGenerator.generateForCLI(config: config)
        #expect(output.contains("# mytool"))
        #expect(output.contains("swift run mytool"))
    }
}
