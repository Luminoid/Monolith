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
    func `strict concurrency feature emits nothing at tools 6_2`() {
        // Swift 6.2 makes strict concurrency the language default; the legacy
        // .enableExperimentalFeature("StrictConcurrency") shim is obsolete and
        // produces a build warning. The feature flag stays accepted (config
        // backwards-compat) but generator emission is a no-op.
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

        #expect(!output.contains("StrictConcurrency"))
        #expect(!output.contains("enableExperimentalFeature"))
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

    // MARK: - v0.2 flags

    @Test
    func `packageDeps merge into every target's dependencies once`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibAdapters", dependencies: ["MultiLib"]),
                TargetDefinition(name: "MultiLibDebug", dependencies: ["MultiLib", "LumiKitUI"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            packageDeps: ["LumiKitUI"]
        )
        let output = PackageSwiftGenerator.generate(config: config)

        // LumiKit package dep appears exactly once (deduped)
        #expect(output.components(separatedBy: "Luminoid/LumiKit.git").count - 1 == 1)
        // Each target has the LumiKitUI product (3 targets × 1 = 3 occurrences)
        #expect(output.components(separatedBy: ".product(name: \"LumiKitUI\", package: \"LumiKit\")").count - 1 == 3)
    }

    @Test
    func `xctest target emits XCTest linker setting`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            xctestTargets: ["MultiLibTesting"]
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".linkedFramework(\"XCTest\")"))
        // Linker setting attached only to MultiLibTesting, not to MultiLib core
        #expect(output.components(separatedBy: "linkerSettings:").count - 1 == 1)
    }

    @Test
    func `target resources emit process declarations`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibDebug", dependencies: ["MultiLib"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            targetResources: ["MultiLibDebug": ["Assets", "Templates"]]
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".process(\"Assets\")"))
        #expect(output.contains(".process(\"Templates\")"))
        // Resources block emitted exactly once (only for MultiLibDebug)
        #expect(output.components(separatedBy: "resources:").count - 1 == 1)
    }

    @Test
    func `external packages override hardcoded registry`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "Core", dependencies: ["ExtPkg"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            externalPackages: [
                ExternalPackage(
                    name: "ExtPkg",
                    url: "https://example.com/ExtPkg",
                    requirement: "from: \"0.1.0\"",
                    packageName: nil
                ),
            ]
        )
        let output = PackageSwiftGenerator.generate(config: config)

        #expect(output.contains(".package(url: \"https://example.com/ExtPkg\", from: \"0.1.0\")"))
        #expect(output.contains(".product(name: \"ExtPkg\", package: \"ExtPkg\")"))
    }

    @Test
    func `combined v0_2 flags produce a valid multi-target framework package`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibAdapters", dependencies: ["MultiLib"]),
                TargetDefinition(name: "MultiLibDebug", dependencies: ["MultiLib"]),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
                TargetDefinition(name: "MultiLibReporting", dependencies: ["MultiLib"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib", "MultiLibAdapters", "MultiLibDebug"],
            author: "Test",
            licenseType: .mit,
            packageDeps: ["LumiKitUI"],
            xctestTargets: ["MultiLibTesting"],
            targetResources: ["MultiLibDebug": ["Resources"]]
        )
        let output = PackageSwiftGenerator.generate(config: config)

        // Five products
        #expect(output.components(separatedBy: ".library(name:").count - 1 == 5)
        // LumiKit referenced once in package dependencies
        #expect(output.components(separatedBy: "Luminoid/LumiKit.git").count - 1 == 1)
        // Each of 5 targets gets LumiKitUI product wired in
        #expect(output.components(separatedBy: ".product(name: \"LumiKitUI\"").count - 1 == 5)
        // MainActor isolation on 3 targets
        #expect(output.components(separatedBy: ".defaultIsolation(MainActor.self)").count - 1 == 3)
        // XCTest linker on the testing target only
        #expect(output.contains(".linkedFramework(\"XCTest\")"))
        // Resources only on debug
        #expect(output.contains(".process(\"Resources\")"))
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
