import Foundation
import Testing
@testable import MonolithLib

@Suite("SPMAppGenerator")
struct SPMAppGeneratorTests {
    private func makeConfig(
        lumiKit: Bool = false,
        snapKit: Bool = false,
        lottie: Bool = false,
        localization: Bool = false,
        macCatalyst: Bool = false,
        name: String = "TestApp"
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if lumiKit { features.insert(.lumiKit) }
        if snapKit { features.insert(.snapKit) }
        if lottie { features.insert(.lottie) }
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
            author: "Test"
        )
    }

    @Test("generates swift-tools-version 6.2")
    func swiftToolsVersion() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(output.contains("// swift-tools-version: 6.2"))
    }

    @Test("uses executableTarget for app")
    func executableTarget() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(output.contains(".executableTarget("))
    }

    @Test("generates test target")
    func generatesTestTarget() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(output.contains(".testTarget("))
        #expect(output.contains("\"TestAppTests\""))
    }

    @Test("LumiKit adds dependency")
    func lumiKitDependency() {
        let output = SPMAppGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("LumiKit.git"))
        #expect(output.contains("LumiKitUI"))
        #expect(output.contains(DependencyVersion.lumiKit))
    }

    @Test("SnapKit adds dependency")
    func snapKitDependency() {
        let output = SPMAppGenerator.generate(config: makeConfig(snapKit: true))
        #expect(output.contains("SnapKit.git"))
        #expect(output.contains(DependencyVersion.snapKit))
    }

    @Test("Lottie adds dependency")
    func lottieDependency() {
        let output = SPMAppGenerator.generate(config: makeConfig(lottie: true))
        #expect(output.contains("lottie-spm.git"))
        #expect(output.contains(DependencyVersion.lottie))
    }

    @Test("no package-level dependencies without feature flags")
    func noDependenciesByDefault() {
        let output = SPMAppGenerator.generate(config: makeConfig())
        #expect(!output.contains(".package(url:"))
    }

    @Test("localization adds defaultLocalization and resources")
    func localization() {
        let output = SPMAppGenerator.generate(config: makeConfig(localization: true))
        #expect(output.contains("defaultLocalization: \"en\""))
        #expect(output.contains(".process(\"Resources\")"))
    }

    @Test("Mac Catalyst adds macCatalyst platform")
    func macCatalystPlatform() {
        let output = SPMAppGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains(".macCatalyst(.v18)"))
    }
}
