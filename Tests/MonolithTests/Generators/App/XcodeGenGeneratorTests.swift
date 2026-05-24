import Foundation
import Testing
@testable import MonolithLib

struct XcodeGenGeneratorTests {
    /// SnapKit + LookinServer come via the `--use-packages` synthesis (v0.3.0+):
    /// the booleans add the equivalent `ExternalPackage` entries + target-dep
    /// product name. LumiKit + Lottie stay as feature flags.
    private func makeConfig(
        lumiKit: Bool = false,
        snapKit: Bool = false,
        lottie: Bool = false,
        lookin: Bool = false,
        macCatalyst: Bool = false,
        devTooling: Bool = false
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if lumiKit { features.insert(.lumiKit) }
        if lottie { features.insert(.lottie) }
        if devTooling { features.insert(.devTooling) }

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
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeGen,
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
    func `basic project.yml structure`() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(output.contains("name: TestApp"))
        #expect(output.contains("iOS: 18.0"))
        #expect(output.contains("type: application"))
        #expect(output.contains("platform: iOS"))
        #expect(output.contains("PRODUCT_BUNDLE_IDENTIFIER: com.test.app"))
    }

    @Test
    func `target present`() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(output.contains("TestAppTests:"))
        #expect(output.contains("type: bundle.unit-test"))
        #expect(output.contains("target: TestApp"))
    }

    /// Required for Mac App Store distribution. Archive succeeds without it
    /// (Xcode emits a warning, not an error), but App Store Connect silently
    /// rejects the upload. Generic `public.app-category.utilities` default —
    /// adopters override before submission.
    @Test
    func `app target declares LSApplicationCategoryType for App Store uploads`() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(output.contains("INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.utilities"))
    }

    @Test
    func `LumiKit dependency added`() {
        let output = XcodeGenGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("package: LumiKit"))
        #expect(output.contains("LumiKit.git"))
    }

    @Test
    func `SnapKit dependency added`() {
        let output = XcodeGenGenerator.generate(config: makeConfig(snapKit: true))
        #expect(output.contains("package: SnapKit"))
        #expect(output.contains("SnapKit.git"))
    }

    @Test
    func `Lottie dependency added`() {
        let output = XcodeGenGenerator.generate(config: makeConfig(lottie: true))
        #expect(output.contains("package: Lottie"))
        #expect(output.contains("lottie-spm.git"))
    }

    @Test
    func `LookinServer dependency added with iOS platform filter`() {
        let output = XcodeGenGenerator.generate(config: makeConfig(lookin: true))
        #expect(output.contains("package: LookinServer"))
        #expect(output.contains("LookinServer.git"))
        #expect(output.contains("platforms: [iOS]"))
    }

    @Test
    func `Mac Catalyst adds macCatalyst deployment target`() {
        let output = XcodeGenGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("macCatalyst: 18.0"))
        #expect(output.contains("supportedDestinations"))
    }

    @Test
    func `no package dependencies without features`() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(!output.contains("packages:"))
        #expect(!output.contains("package: LumiKit"))
        #expect(!output.contains("package: SnapKit"))
    }

    @Test
    func `bundle prefix extracted correctly`() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(output.contains("bundleIdPrefix: com.test"))
    }

    @Test
    func `devTooling adds build phase scripts`() {
        let output = XcodeGenGenerator.generate(config: makeConfig(devTooling: true))
        #expect(output.contains("preBuildScripts:"))
        #expect(output.contains("name: SwiftFormat"))
        #expect(output.contains("swiftformat"))
        #expect(output.contains("postCompileScripts:"))
        #expect(output.contains("name: SwiftLint"))
        #expect(output.contains("swiftlint"))
    }

    @Test
    func `no build phase scripts without devTooling`() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(!output.contains("preBuildScripts:"))
        #expect(!output.contains("postCompileScripts:"))
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
            projectSystem: .xcodeProj,
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
    func `external package emits packages block entry`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["Prism"]
        )
        let output = XcodeGenGenerator.generate(config: config)
        #expect(output.contains("packages:"))
        #expect(output.contains("  Prism:"))
        #expect(output.contains("    url: https://github.com/luminoid/Prism"))
        #expect(output.contains("    from: \"0.3.0\""))
    }

    @Test
    func `external package with branch requirement emits verbatim YAML`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Beta", url: "https://example.com/Beta", requirement: "branch: \"main\"", packageName: nil)],
            targetDependencies: ["Beta"]
        )
        let output = XcodeGenGenerator.generate(config: config)
        #expect(output.contains("  Beta:"))
        #expect(output.contains("    branch: \"main\""))
    }

    @Test
    func `target-deps emits package + product entry under app target deps`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["Prism"]
        )
        let output = XcodeGenGenerator.generate(config: config)
        #expect(output.contains("      - package: Prism"))
        #expect(output.contains("        product: Prism"))
    }

    @Test
    func `target-deps with multi-product package references custom packageName`() {
        let config = makeConfigWithExternals(
            externalPackages: [
                ExternalPackage(name: "PrismCore", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: "Prism"),
            ],
            targetDependencies: ["PrismCore"]
        )
        let output = XcodeGenGenerator.generate(config: config)
        // Both products under one package entry
        #expect(output.contains("  Prism:"))
        #expect(output.contains("      - package: Prism"))
        #expect(output.contains("        product: PrismCore"))
    }

    @Test
    func `target-deps does not duplicate built-in feature deps (Lottie)`() {
        // --features lottie + --target-deps Lottie must not emit two entries.
        // (SnapKit / LookinServer no longer exist as features.)
        let config = makeConfigWithExternals(
            externalPackages: [],
            targetDependencies: ["Lottie"],
            features: [.lottie]
        )
        let output = XcodeGenGenerator.generate(config: config)
        let count = output.components(separatedBy: "      - package: Lottie").count - 1
        #expect(count == 1, "Expected exactly one Lottie package entry, got \(count)")
    }

    @Test
    func `single external + multi-product target-deps routes all products to one package`() {
        // The Prism case: one --external-packages 'Prism=...' + --target-deps 'PrismCore,PrismUI'
        // should emit two TargetDeps, both with package=Prism and distinct product names.
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["PrismCore", "PrismUI"]
        )
        let output = XcodeGenGenerator.generate(config: config)
        // Both products reference the single declared package
        #expect(output.contains("      - package: Prism\n        product: PrismCore"))
        #expect(output.contains("      - package: Prism\n        product: PrismUI"))
        // Only one packages: block entry for Prism
        let count = output.components(separatedBy: "  Prism:\n    url:").count - 1
        #expect(count == 1, "Expected exactly one Prism package declaration, got \(count)")
    }

    @Test
    func `path-form external emits path key instead of url + requirement`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "/Users/me/Projects/Prism", requirement: "", packageName: nil)],
            targetDependencies: ["PrismCore", "PrismUI"]
        )
        let output = XcodeGenGenerator.generate(config: config)
        #expect(output.contains("  Prism:\n    path: /Users/me/Projects/Prism"))
        // Should NOT emit url: or from: lines for this package
        #expect(!output.contains("  Prism:\n    url:"))
        // Target deps still route correctly
        #expect(output.contains("      - package: Prism\n        product: PrismCore"))
        #expect(output.contains("      - package: Prism\n        product: PrismUI"))
    }

    @Test
    func `relative path external resolves through emit`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "LumiKit", url: "../LumiKit", requirement: "", packageName: nil)],
            targetDependencies: ["LumiKitUI"]
        )
        let output = XcodeGenGenerator.generate(config: config)
        #expect(output.contains("  LumiKit:\n    path: ../LumiKit"))
    }
}
