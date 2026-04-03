import Foundation
import Testing
@testable import MonolithLib

struct SPMAppGeneratorTests {
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
        if snapKit { features.insert(.snapKit) }
        if lottie { features.insert(.lottie) }
        if lookin { features.insert(.lookin) }
        if localization { features.insert(.localization) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

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
            licenseType: .proprietary
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
}
