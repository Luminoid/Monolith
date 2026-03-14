import Foundation
import Testing
@testable import MonolithLib

@Suite("ReadmeGenerator")
struct ReadmeGeneratorTests {
    // MARK: - App README

    @Test("app README has title and Monolith attribution")
    func appReadmeBasic() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .spm,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test"
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("# MyApp"))
        #expect(output.contains("Monolith"))
    }

    @Test("app README shows tech stack based on features")
    func appReadmeTechStack() {
        let config = AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .spm,
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

    @Test("app README shows XcodeGen commands for xcodegen project system")
    func appReadmeXcodeGen() {
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
        #expect(output.contains("xcodebuild"))
    }

    @Test("app README shows swift build for SPM project system")
    func appReadmeSPM() {
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
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("swift build"))
    }

    // MARK: - Package README

    @Test("package README has target table")
    func packageReadmeTargetTable() {
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

    @Test("package README uses xcodebuild when defaultIsolation enabled")
    func packageReadmeDefaultIsolation() {
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

    @Test("CLI README has run command")
    func cliReadmeRunCommand() {
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
