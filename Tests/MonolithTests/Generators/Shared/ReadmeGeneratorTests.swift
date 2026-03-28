import Foundation
import Testing
@testable import MonolithLib

struct ReadmeGeneratorTests {
    // MARK: - App README

    @Test
    func `app README has title and Monolith attribution`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("# MyApp"))
        #expect(output.contains("Monolith"))
    }

    @Test
    func `app README shows tech stack based on features`() {
        let config = AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [.swiftData, .lumiKit, .snapKit, .combine],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("SwiftData"))
        #expect(output.contains("LumiKit"))
        #expect(output.contains("SnapKit"))
        #expect(output.contains("Combine"))
    }

    @Test
    func `app README shows XcodeGen commands for xcodegen project system`() {
        let config = AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("xcodegen generate"))
        #expect(output.contains("make build"))
    }

    @Test
    func `app README shows open xcodeproj for xcodeProj project system`() {
        let config = AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("open TestApp.xcodeproj"))
        #expect(output.contains("make build"))
    }

    // MARK: - Package README

    @Test
    func `package README has target table`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("# MyLib"))
        #expect(output.contains("| Core |"))
        #expect(output.contains("| UI | Core |"))
    }

    @Test
    func `package README uses xcodebuild when defaultIsolation enabled`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("xcodebuild build"))
        #expect(output.contains("-scheme MyLib-Package"))
        #expect(!output.contains("swift build"))
    }

    // MARK: - CLI README

    @Test
    func `CLI README has run command`() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: true,
            features: [],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForCLI(config: config)
        #expect(output.contains("# mytool"))
        #expect(output.contains("swift run mytool"))
    }
}
