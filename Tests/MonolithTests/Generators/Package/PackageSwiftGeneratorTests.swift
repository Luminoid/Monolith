import Foundation
import Testing
@testable import MonolithLib

struct PackageSwiftGeneratorTests {
    @Test
    func `single target package`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
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

    @Test
    func `multi-target package with inter-target dependency`() {
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
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".library(name: \"MyLibCore\""))
        #expect(output.contains(".library(name: \"MyLibUI\""))
        #expect(output.contains("\"MyLibCore\""))
        #expect(output.contains("\"MyLibCoreTests\""))
        #expect(output.contains("\"MyLibUITests\""))
    }

    @Test
    func `defaultIsolation for selected targets`() {
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
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".defaultIsolation(MainActor.self)"))
    }

    @Test
    func `strict concurrency setting`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.strictConcurrency],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains("StrictConcurrency"))
    }

    @Test
    func `external SnapKit dependency`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: ["SnapKit"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains("SnapKit/SnapKit.git"))
        #expect(output.contains(".product(name: \"SnapKit\""))
    }

    @Test
    func `external Lottie dependency`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: ["Lottie"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains("airbnb/lottie-spm.git"))
        #expect(output.contains(".product(name: \"Lottie\", package: \"lottie-spm\")"))
    }

    @Test
    func `external LumiKitUI dependency`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: ["LumiKitUI"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains("Luminoid/LumiKit.git"))
        #expect(output.contains(".product(name: \"LumiKitUI\", package: \"LumiKit\")"))
    }

    @Test
    func `LumiKit package URL appears once when multiple products are referenced`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MyLibCore", dependencies: ["LumiKitCore"]),
                TargetDefinition(name: "MyLibUI", dependencies: ["MyLibCore", "LumiKitUI", "LumiKitLottie"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        // Package URL listed exactly once in `dependencies:` despite three product references
        let packageURLCount = output.components(separatedBy: "Luminoid/LumiKit.git").count - 1
        #expect(packageURLCount == 1)

        // All three products wired into their respective targets
        #expect(output.contains(".product(name: \"LumiKitCore\", package: \"LumiKit\")"))
        #expect(output.contains(".product(name: \"LumiKitUI\", package: \"LumiKit\")"))
        #expect(output.contains(".product(name: \"LumiKitLottie\", package: \"LumiKit\")"))
    }

    @Test
    func `multiple platforms`() {
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
            licenseType: .mit
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".iOS(.v18)"))
        #expect(output.contains(".macCatalyst(.v18)"))
        #expect(output.contains(".macOS(.v15)"))
    }
}
