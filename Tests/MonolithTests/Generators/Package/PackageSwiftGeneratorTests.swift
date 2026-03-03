import Foundation
import Testing
@testable import MonolithLib

@Suite("PackageSwiftGenerator")
struct PackageSwiftGeneratorTests {
    @Test("single target package")
    func singleTarget() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains("swift-tools-version: 6.2"))
        #expect(output.contains("name: \"MyLib\""))
        #expect(output.contains(".iOS(.v18)"))
        #expect(output.contains(".library(name: \"MyLib\""))
        #expect(output.contains(".target("))
        #expect(output.contains(".testTarget("))
        #expect(output.contains("\"MyLibTests\""))
    }

    @Test("multi-target package with inter-target dependency")
    func multiTarget() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "MyLibCore", dependencies: []),
                TargetDefinition(name: "MyLibUI", dependencies: ["MyLibCore"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".library(name: \"MyLibCore\""))
        #expect(output.contains(".library(name: \"MyLibUI\""))
        #expect(output.contains("\"MyLibCore\""))
        #expect(output.contains("\"MyLibCoreTests\""))
        #expect(output.contains("\"MyLibUITests\""))
    }

    @Test("defaultIsolation for selected targets")
    func defaultIsolation() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "MyLibCore", dependencies: []),
                TargetDefinition(name: "MyLibUI", dependencies: ["MyLibCore"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".defaultIsolation(MainActor.self)"))
    }

    @Test("strict concurrency setting")
    func strictConcurrency() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.strictConcurrency],
            mainActorTargets: [],
            author: "Test",
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains("StrictConcurrency"))
    }

    @Test("external SnapKit dependency")
    func externalSnapKit() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: ["SnapKit"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains("SnapKit/SnapKit.git"))
        #expect(output.contains(".product(name: \"SnapKit\""))
    }

    @Test("multiple platforms")
    func multiplePlatforms() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [
                PlatformVersion(platform: "iOS", version: "18.0"),
                PlatformVersion(platform: "macCatalyst", version: "18.0"),
                PlatformVersion(platform: "macOS", version: "15.0"),
            ],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".iOS(.v18)"))
        #expect(output.contains(".macCatalyst(.v18)"))
        #expect(output.contains(".macOS(.v15)"))
    }
}
