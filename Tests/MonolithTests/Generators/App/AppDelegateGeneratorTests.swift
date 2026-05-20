import Foundation
import Testing
@testable import MonolithLib

struct AppDelegateGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        coreData: Bool = false,
        cloudKit: Bool = false,
        notifications: Bool = false,
        lumiKit: Bool = false,
        macCatalyst: Bool = false,
        tabs: [TabDefinition] = [],
        name: String = "TestApp"
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }
        if coreData { features.insert(.coreData) }
        if cloudKit { features.insert(.cloudKit) }
        if notifications { features.insert(.notifications) }
        if lumiKit { features.insert(.lumiKit) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeProj,
            tabs: tabs,
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

    // MARK: - Core Data + CloudKit

    @Test
    func `Core Data adds CoreData import and stack reference`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(coreData: true, name: "MyApp"))
        #expect(output.contains("import CoreData"))
        #expect(output.contains("MyAppCoreDataStack.shared"))
    }

    @Test
    func `CloudKit registers for remote notifications`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(cloudKit: true))
        #expect(output.contains("application.registerForRemoteNotifications()"))
        #expect(output.contains("didRegisterForRemoteNotificationsWithDeviceToken"))
        #expect(output.contains("didFailToRegisterForRemoteNotificationsWithError"))
    }

    @Test
    func `CloudKit implies Core Data scaffolding when no SwiftData`() {
        // resolvedFeatures auto-derives coreData when cloudKit is set without a persistence layer.
        let output = AppDelegateGenerator.generate(config: makeConfig(cloudKit: true))
        #expect(output.contains("import CoreData"))
    }

    @Test
    func `no remote notification scaffolding without CloudKit`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("registerForRemoteNotifications"))
        #expect(!output.contains("didRegisterForRemoteNotificationsWithDeviceToken"))
    }

    // MARK: - User Notifications

    @Test
    func `notifications adds UNUserNotificationCenter import and delegate`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(notifications: true))
        #expect(output.contains("import UserNotifications"))
        #expect(output.contains("UNUserNotificationCenterDelegate"))
        #expect(output.contains("UNUserNotificationCenter.current().delegate = self"))
    }

    @Test
    func `notifications adds foreground presentation handler`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(notifications: true))
        #expect(output.contains("willPresent notification"))
        #expect(output.contains(".banner"))
        #expect(output.contains("didReceive response"))
    }

    @Test
    func `no notification scaffolding without feature`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import UserNotifications"))
        #expect(!output.contains("UNUserNotificationCenterDelegate"))
    }

    // MARK: - Mac Catalyst Tab Menu

    @Test
    func `tabs generate per-tab keyboard shortcuts in Mac menu`() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house"),
            TabDefinition(name: "Settings", icon: "gearshape"),
        ]
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: true, tabs: tabs))
        #expect(output.contains("UIMenu(title: \"Tabs\""))
        #expect(output.contains("title: \"Home\""))
        #expect(output.contains("title: \"Settings\""))
        #expect(output.contains("input: \"1\""))
        #expect(output.contains("input: \"2\""))
        #expect(output.contains("handleTabMenu"))
        #expect(output.contains("macMenuSwitchTab"))
    }

    @Test
    func `Mac menu without tabs only has Refresh command`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("handleRefreshMenu"))
        #expect(!output.contains("handleTabMenu"))
        #expect(!output.contains("UIMenu(title: \"Tabs\""))
    }
}
