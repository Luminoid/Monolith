import Foundation
import Testing
@testable import MonolithLib

struct AppDelegateGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        lumiKit: Bool = false,
        macCatalyst: Bool = false,
        name: String = "TestApp"
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }
        if lumiKit { features.insert(.lumiKit) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `basic app delegate imports UIKit`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("import UIKit"))
        #expect(output.contains("@main"))
        #expect(output.contains("class AppDelegate"))
        #expect(output.contains("didFinishLaunchingWithOptions"))
    }

    @Test
    func `SwiftData adds import and container`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("var modelContainer"))
        #expect(output.contains("createModelContainer"))
        #expect(output.contains("ModelContainer"))
    }

    @Test
    func `LumiKit adds import and configuration`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("configureLumiKit"))
        #expect(output.contains("LMKThemeManager"))
    }

    @Test
    func `Mac Catalyst adds menu builder`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("buildMenu"))
        #expect(output.contains("UIKeyCommand"))
        #expect(output.contains("handleRefreshMenu"))
    }

    @Test
    func `4-phase boot pattern present`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("Phase 1"))
        #expect(output.contains("Phase 2"))
        #expect(output.contains("Phase 3"))
        #expect(output.contains("Phase 4"))
    }

    @Test
    func `memory warning observer`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("setupMemoryWarningObserver"))
        #expect(output.contains("handleMemoryWarning"))
        #expect(output.contains("AppNotification.memoryWarningReceived"))
    }

    @Test
    func `scene configuration present`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("configurationForConnecting"))
        #expect(output.contains("Default Configuration"))
    }

    @Test
    func `deferred work present`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("deferPostLaunchWork"))
        #expect(output.contains("Task { @MainActor in"))
    }

    @Test
    func `no SwiftData without feature flag`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import SwiftData"))
        #expect(!output.contains("modelContainer"))
    }

    @Test
    func `no LumiKit without feature flag`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import LumiKitUI"))
        #expect(!output.contains("configureLumiKit"))
    }

    @Test
    func `app name in menu title`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: true, name: "MyApp"))
        #expect(output.contains("MyApp"))
    }
}
