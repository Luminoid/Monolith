import Foundation
import Testing
@testable import MonolithLib

struct XcodeGenGeneratorTests {
    private func makeConfig(
        lumiKit: Bool = false,
        snapKit: Bool = false,
        lottie: Bool = false,
        macCatalyst: Bool = false,
        devTooling: Bool = false
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if lumiKit { features.insert(.lumiKit) }
        if snapKit { features.insert(.snapKit) }
        if lottie { features.insert(.lottie) }
        if devTooling { features.insert(.devTooling) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test"
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
}
