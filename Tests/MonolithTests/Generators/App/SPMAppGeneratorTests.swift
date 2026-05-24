import Foundation
import Testing
@testable import MonolithLib

struct SPMAppGeneratorTests {
    /// Test fixture builder. SnapKit + LookinServer come via the `--use-packages`
    /// synthesis (v0.3.0+), so their booleans synthesize the equivalent
    /// `ExternalPackage` entries + add the product name to `targetDependencies`.
    /// Lottie + LumiKit stay as feature flags (they have generator integration
    /// beyond just dep wiring).
    private func makeConfig(
        lumiKit: Bool = false,
        snapKit: Bool = false,
        lottie: Bool = false,
        lookin: Bool = false,
        localization: Bool = false,
        macCatalyst: Bool = false,
        name: String = "TestApp"
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if lumiKit { features.insert(.lumiKit) }
        if lottie { features.insert(.lottie) }
        if localization { features.insert(.localization) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        var externalPackages: [ExternalPackage] = []
        var targetDeps: [String] = []
        if snapKit, let entry = KnownPackages.registry["SnapKit"] {
            externalPackages.append(ExternalPackage(name: entry.name, url: entry.url, requirement: "from: \"\(entry.defaultVersion)\"", packageName: nil))
            targetDeps.append("SnapKit")
        }
        if lookin, let entry = KnownPackages.registry["LookinServer"] {
            externalPackages.append(ExternalPackage(name: entry.name, url: entry.url, requirement: "from: \"\(entry.defaultVersion)\"", packageName: nil))
            targetDeps.append("LookinServer")
        }

        return AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .spm,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary,
            externalPackages: externalPackages,
            targetDependencies: targetDeps
        )
    }

    @Test
    func `generates swift-tools-version 6.2`() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(output.contains("// swift-tools-version: 6.2"))
    }

    @Test
    func `uses executableTarget for app`() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(output.contains(".executableTarget("))
    }

    @Test
    func `generates test target`() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(output.contains(".testTarget("))
        #expect(output.contains("\"TestAppTests\""))
    }

    @Test
    func `LumiKit adds dependency`() {
        let output = SPMAppGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("LumiKit.git"))
        #expect(output.contains("LumiKitUI"))
        #expect(output.contains(DependencyVersion.lumiKit))
    }

    @Test
    func `SnapKit adds dependency`() {
        let output = SPMAppGenerator.generate(config: makeConfig(snapKit: true))
        #expect(output.contains("SnapKit.git"))
        #expect(output.contains(DependencyVersion.snapKit))
    }

    @Test
    func `Lottie adds dependency`() {
        let output = SPMAppGenerator.generate(config: makeConfig(lottie: true))
        #expect(output.contains("lottie-spm.git"))
        #expect(output.contains(DependencyVersion.lottie))
    }

    @Test
    func `LookinServer adds dependency with iOS platform condition`() {
        let output = SPMAppGenerator.generate(config: makeConfig(lookin: true))
        #expect(output.contains("LookinServer.git"))
        #expect(output.contains(DependencyVersion.lookin))
        #expect(output.contains("condition: .when(platforms: [.iOS])"))
    }

    @Test
    func `no package-level dependencies without feature flags`() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(!output.contains(".package(url:"))
    }

    @Test
    func `localization adds defaultLocalization and resources`() {
        let output = SPMAppGenerator.generate(config: makeConfig(localization: true))
        #expect(output.contains("defaultLocalization: \"en\""))
        #expect(output.contains(".process(\"Resources\")"))
    }

    @Test
    func `Mac Catalyst adds macCatalyst platform`() {
        let output = SPMAppGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains(".macCatalyst(.v18)"))
    }

    // MARK: - External Packages

    private func makeConfigWithExternals(
        externalPackages: [ExternalPackage],
        targetDependencies: [String],
        features: Set<AppFeature> = []
    ) -> AppConfig {
        AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .spm,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary,
            externalPackages: externalPackages,
            targetDependencies: targetDependencies
        )
    }

    @Test
    func `external package emits .package(url:, from:) line`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["Prism"]
        )
        let output = SPMAppGenerator.generate(config: config)
        #expect(output.contains(".package(url: \"https://github.com/luminoid/Prism\", from: \"0.3.0\")"))
    }

    @Test
    func `external package with branch requirement emits verbatim`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Beta", url: "https://example.com/Beta", requirement: "branch: \"main\"", packageName: nil)],
            targetDependencies: ["Beta"]
        )
        let output = SPMAppGenerator.generate(config: config)
        #expect(output.contains(".package(url: \"https://example.com/Beta\", branch: \"main\")"))
    }

    @Test
    func `target-deps emits .product(name:, package:) entry`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["Prism"]
        )
        let output = SPMAppGenerator.generate(config: config)
        #expect(output.contains(".product(name: \"Prism\", package: \"Prism\")"))
    }

    @Test
    func `target-deps references separate packageName when provided`() {
        // Multi-product package: --external-packages "PrismCore=...:from \"0.3.0\":Prism"
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "PrismCore", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: "Prism")],
            targetDependencies: ["PrismCore"]
        )
        let output = SPMAppGenerator.generate(config: config)
        #expect(output.contains(".product(name: \"PrismCore\", package: \"Prism\")"))
    }

    @Test
    func `target-deps does not duplicate built-in feature products (Lottie)`() {
        // --features lottie AND --target-deps Lottie: dedupe to one entry.
        // (SnapKit / LookinServer no longer exist as features — they're sourced
        // via --use-packages / --external-packages.)
        let config = makeConfigWithExternals(
            externalPackages: [],
            targetDependencies: ["Lottie"],
            features: [.lottie]
        )
        let output = SPMAppGenerator.generate(config: config)
        let count = output.components(separatedBy: ".product(name: \"Lottie\"").count - 1
        #expect(count == 1, "Expected exactly one Lottie product entry, got \(count)")
    }

    @Test
    func `single external + multi-product target-deps routes all products to that package`() {
        // The Prism case: emit two .product(name:, package:) entries both pointing at Prism.
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["PrismCore", "PrismUI"]
        )
        let output = SPMAppGenerator.generate(config: config)
        #expect(output.contains(".product(name: \"PrismCore\", package: \"Prism\")"))
        #expect(output.contains(".product(name: \"PrismUI\", package: \"Prism\")"))
        // Single .package(url:) line for Prism
        let count = output.components(separatedBy: ".package(url: \"https://github.com/luminoid/Prism\"").count - 1
        #expect(count == 1, "Expected exactly one Prism .package() declaration, got \(count)")
    }

    @Test
    func `path-form external emits .package(name:, path:)`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "/Users/me/Projects/Prism", requirement: "", packageName: nil)],
            targetDependencies: ["PrismCore", "PrismUI"]
        )
        let output = SPMAppGenerator.generate(config: config)
        #expect(output.contains(".package(name: \"Prism\", path: \"/Users/me/Projects/Prism\")"))
        // URL form should NOT appear for this package
        #expect(!output.contains(".package(url: \"/Users/me/Projects/Prism\""))
        // Target-deps still wire correctly via the package name
        #expect(output.contains(".product(name: \"PrismCore\", package: \"Prism\")"))
        #expect(output.contains(".product(name: \"PrismUI\", package: \"Prism\")"))
    }
}
