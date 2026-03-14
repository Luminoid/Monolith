import Foundation
import Testing
@testable import MonolithLib

@Suite("AppDelegateGenerator")
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
            projectSystem: .spm,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test"
        )
    }

    @Test("basic app delegate imports UIKit")
    func basicImports() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("import UIKit"))
        #expect(output.contains("@main"))
        #expect(output.contains("class AppDelegate"))
        #expect(output.contains("didFinishLaunchingWithOptions"))
    }

    @Test("SwiftData adds import and container")
    func swiftDataIntegration() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("var modelContainer"))
        #expect(output.contains("createModelContainer"))
        #expect(output.contains("ModelContainer"))
    }

    @Test("LumiKit adds import and configuration")
    func lumiKitIntegration() {
        let output = AppDelegateGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("configureLumiKit"))
        #expect(output.contains("LMKThemeManager"))
    }

    @Test("Mac Catalyst adds menu builder")
    func macCatalystMenu() {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("buildMenu"))
        #expect(output.contains("UIKeyCommand"))
        #expect(output.contains("handleRefreshMenu"))
    }

    @Test("4-phase boot pattern present")
    func fourPhasePattern() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("Phase 1"))
        #expect(output.contains("Phase 2"))
        #expect(output.contains("Phase 3"))
        #expect(output.contains("Phase 4"))
    }

    @Test("memory warning observer")
    func memoryWarning() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("setupMemoryWarningObserver"))
        #expect(output.contains("handleMemoryWarning"))
        #expect(output.contains("AppNotification.memoryWarningReceived"))
    }

    @Test("scene configuration present")
    func sceneConfig() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("configurationForConnecting"))
        #expect(output.contains("Default Configuration"))
    }

    @Test("deferred work present")
    func deferredWork() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("deferPostLaunchWork"))
        #expect(output.contains("Task { @MainActor in"))
    }

    @Test("no SwiftData without feature flag")
    func noSwiftDataByDefault() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import SwiftData"))
        #expect(!output.contains("modelContainer"))
    }

    @Test("no LumiKit without feature flag")
    func noLumiKitByDefault() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import LumiKitUI"))
        #expect(!output.contains("configureLumiKit"))
    }

    @Test("app name in menu title")
    func appNameInMenu() {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: true, name: "MyApp"))
        #expect(output.contains("MyApp"))
    }
}
