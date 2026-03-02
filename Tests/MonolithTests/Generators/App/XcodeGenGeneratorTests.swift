import Foundation
import Testing
@testable import MonolithLib

@Suite("XcodeGenGenerator")
struct XcodeGenGeneratorTests {

    private func makeConfig(
        lumiKit: Bool = false,
        snapKit: Bool = false,
        lottie: Bool = false,
        macCatalyst: Bool = false
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if lumiKit { features.insert(.lumiKit) }
        if snapKit { features.insert(.snapKit) }
        if lottie { features.insert(.lottie) }

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

    @Test("basic project.yml structure")
    func basicStructure() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(output.contains("name: TestApp"))
        #expect(output.contains("iOS: 18.0"))
        #expect(output.contains("type: application"))
        #expect(output.contains("platform: iOS"))
        #expect(output.contains("PRODUCT_BUNDLE_IDENTIFIER: com.test.app"))
    }

    @Test("test target present")
    func testTarget() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(output.contains("TestAppTests:"))
        #expect(output.contains("type: bundle.unit-test"))
        #expect(output.contains("target: TestApp"))
    }

    @Test("LumiKit dependency added")
    func lumiKitDep() {
        let output = XcodeGenGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("package: LumiKit"))
        #expect(output.contains("LumiKit.git"))
    }

    @Test("SnapKit dependency added")
    func snapKitDep() {
        let output = XcodeGenGenerator.generate(config: makeConfig(snapKit: true))
        #expect(output.contains("package: SnapKit"))
        #expect(output.contains("SnapKit.git"))
    }

    @Test("Lottie dependency added")
    func lottieDep() {
        let output = XcodeGenGenerator.generate(config: makeConfig(lottie: true))
        #expect(output.contains("package: Lottie"))
        #expect(output.contains("lottie-spm.git"))
    }

    @Test("Mac Catalyst adds macCatalyst deployment target")
    func macCatalystTarget() {
        let output = XcodeGenGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("macCatalyst: 18.0"))
        #expect(output.contains("supportedDestinations"))
    }

    @Test("no package dependencies without features")
    func noDeps() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(!output.contains("packages:"))
        #expect(!output.contains("package: LumiKit"))
        #expect(!output.contains("package: SnapKit"))
    }

    @Test("bundle prefix extracted correctly")
    func bundlePrefix() {
        let output = XcodeGenGenerator.generate(config: makeConfig())
        #expect(output.contains("bundleIdPrefix: com.test"))
    }
}
