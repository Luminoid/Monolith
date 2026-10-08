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
        localization: Bool = false,
        widget: Bool = false,
        tabs: [TabDefinition] = [],
        name: String = "TestApp"
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }
        if coreData { features.insert(.coreData) }
        if cloudKit { features.insert(.cloudKit) }
        if notifications { features.insert(.notifications) }
        if lumiKit { features.insert(.lumiKit) }
        if localization { features.insert(.localization) }
        if widget { features.insert(.widget) }

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

    private let twoTabs = [
        TabDefinition(name: "Home", icon: "house"),
        TabDefinition(name: "Settings", icon: "gearshape"),
    ]

    @Test
    func `basic app delegate imports UIKit`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("import UIKit"))
        #expect(output.contains("@main"))
        #expect(output.contains("class AppDelegate"))
        #expect(output.contains("didFinishLaunchingWithOptions"))
    }

    @Test
    func `LumiKit adds import and configuration`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("configureLumiKit"))
        #expect(output.contains("        LMKTheme.apply(.testApp)"))
        #expect(!output.contains("LMKThemeManager"))
    }

    /// The launch work that used to run as a fourth phase (an empty, untracked
    /// `Task`) is gone: deferred work belongs to the scene's once-per-process
    /// `deferredLaunchWork`.
    @Test
    func `3-phase boot pattern with no untracked deferred task`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("// Phase 1: Core Infrastructure"))
        #expect(output.contains("// Phase 2: System Services"))
        #expect(output.contains("// Phase 3: Configuration"))
        #expect(!output.contains("Phase 4"))
        #expect(!output.contains("deferPostLaunchWork"))
        #expect(!output.contains("Task {"))
    }

    @Test
    func `empty launch phases carry a placeholder comment`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("        // Phase 1: Core Infrastructure\n        // Persistence and design-system setup go here\n"))
        #expect(output.contains("        // Phase 2: System Services\n        // Notification delegates and background tasks go here\n"))
    }

    /// Regression: a launch method whose phases hold only comments ended in
    /// `return true` as its only statement, which the generated SwiftFormat
    /// (`redundantReturn`) and SwiftLint (`implicit_return`) configs reject, so
    /// a minimal app failed its own `make check`.
    @Test
    func `launch method returns implicitly only when no phase has a statement`() {
        let bare = AppDelegateGenerator.generate(config: makeConfig())
        #expect(bare.contains("        // Add migration or cache setup here\n\n        true\n    }\n"))
        #expect(!bare.contains("return true"))

        let withStatement = AppDelegateGenerator.generate(config: makeConfig(notifications: true))
        #expect(withStatement.contains("        // Add migration or cache setup here\n\n        return true\n    }\n"))
    }

    /// The relay re-posted the system's memory warning under an app name that
    /// nothing observed; screens observe the system notification directly.
    @Test
    func `no memory warning relay`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("setupMemoryWarningObserver"))
        #expect(!output.contains("handleMemoryWarning"))
        #expect(!output.contains("memoryWarningReceived"))
    }

    @Test
    func `scene configuration present`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("configurationForConnecting"))
        #expect(output.contains("Default Configuration"))
    }

    @Test
    func `no LumiKit without feature flag`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import LumiKitUI"))
        #expect(!output.contains("configureLumiKit"))
    }

    @Test
    func `generated delegate closes its scope without a trailing blank line`() {
        for config in [makeConfig(), makeConfig(swiftData: true, cloudKit: true, tabs: twoTabs), makeConfig(lumiKit: true)] {
            let output = AppDelegateGenerator.generate(config: config)
            #expect(output.hasSuffix("    }\n}\n"))
            #expect(!output.contains("\n\n}\n"))
        }
    }

    // MARK: - SwiftData

    @Test
    func `SwiftData container is a lazy non-optional property built in phase 1`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("    private(set) lazy var modelContainer: ModelContainer = createModelContainer()"))
        #expect(!output.contains("ModelContainer!"))
        #expect(!output.contains("modelContainer = createModelContainer()\n"))
        #expect(output.contains("        // Phase 1: Core Infrastructure\n        _ = modelContainer\n"))
    }

    /// The container registers the app's models through `AppSchema.models`
    /// (declared next to `SampleItem`), never an empty schema.
    @Test
    func `SwiftData schema registers AppSchema models`() {
        for cloudKit in [false, true] {
            let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKit: cloudKit))
            #expect(output.contains("let schema = Schema(AppSchema.models)"))
            #expect(!output.contains("Schema(["))
            #expect(!output.contains("Add your @Model types here"))
        }
    }

    /// Regression: a fresh install has no Application Support folder, and the
    /// first launch (including every app-hosted test run on a new simulator)
    /// logged a screenful of Core Data "Failed to stat path" errors before
    /// SwiftData created it. Every container is now built through a helper that
    /// creates the store's folder first.
    @Test
    func `SwiftData creates the store folder before building any container`() {
        for cloudKit in [false, true] {
            let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKit: cloudKit))
            #expect(output.contains("""
                private func makeContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
                    try? FileManager.default.createDirectory(at: configuration.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    return try ModelContainer(for: schema, configurations: [configuration])
                }
            """))
            // The helper is the only place a container is built.
            #expect(output.components(separatedBy: "ModelContainer(for:").count == 2)
            #expect(output.components(separatedBy: "try makeContainer(schema: schema, configuration: configuration)").count == (cloudKit ? 3 : 2))
        }
    }

    /// Without CloudKit the store location and CloudKit database are both
    /// explicit: `.automatic` would move the store once an App Group appears
    /// and would sync once an iCloud entitlement appears.
    @Test
    func `SwiftData without CloudKit pins the store and never syncs`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .none)"))
        #expect(!output.contains("ModelConfiguration(schema: schema)\n"))
        #expect(!output.contains(".private("))
        #expect(!output.contains("cloudKitEnabledKey"))
        #expect(!output.contains("isCloudKitEnabled"))
    }

    @Test
    func `SwiftData with a widget keeps its store in the App Group`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, widget: true))
        #expect(output.contains("groupContainer: .identifier(AppGroup.identifier)"))
        #expect(!output.contains("groupContainer: .none"))
    }

    /// The SwiftData CloudKit opt-in mirrors the Core Data stack: a UserDefaults
    /// flag that defaults off, never on in an app-hosted test run, and a local
    /// fallback when the CloudKit container fails to load.
    @Test
    func `SwiftData CloudKit sync is opt-in with a test-host guard and a local fallback`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKit: true))
        #expect(output.contains("static let cloudKitEnabledKey = \"cloudKitSyncEnabled\""))
        #expect(output.contains("private(set) var isCloudKitEnabled = false"))
        #expect(output.contains("""
                let wantsCloudKit = UserDefaults.standard.bool(forKey: Self.cloudKitEnabledKey)
                    && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        """))
        #expect(output.contains("cloudKitDatabase: .private(\"iCloud.com.test.app\")"))
        #expect(output.contains("ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .none)"))
        // The CloudKit attempt sits inside the opt-in branch and falls through
        // to the local container when it throws.
        guard let gate = output.range(of: "if wantsCloudKit {"),
              let cloudKit = output.range(of: ".private(\"iCloud.com.test.app\")"),
              let fallback = output.range(of: "running local-only this launch"),
              let local = output.range(of: "cloudKitDatabase: .none")
        else {
            Issue.record("missing CloudKit opt-in structure")
            return
        }
        #expect(gate.lowerBound < cloudKit.lowerBound)
        #expect(cloudKit.lowerBound < fallback.lowerBound)
        #expect(fallback.lowerBound < local.lowerBound)
        // Only the local load is fatal.
        #expect(output.components(separatedBy: "fatalError(").count - 1 == 1)
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

    /// Regression: registration ran with sync off (the default), so every
    /// unsigned launch and app-hosted test run logged "no valid aps-environment
    /// entitlement". It now runs only when phase 1 turned sync on.
    @Test
    func `remote notification registration waits for sync to be on`() {
        let coreData = AppDelegateGenerator.generate(config: makeConfig(coreData: true, cloudKit: true, name: "MyApp"))
        #expect(coreData.contains("""
                // Phase 2: System Services
                // CloudKit's silent pushes, needed only while sync is on.
                if MyAppCoreDataStack.shared.isCloudKitEnabled {
                    application.registerForRemoteNotifications()
                }

        """))
        let swiftData = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKit: true))
        #expect(swiftData.contains("""
                if isCloudKitEnabled {
                    application.registerForRemoteNotifications()
                }
        """))
    }

    // MARK: - Failure logging

    /// Failure paths log through LMKLogger or the shared `Logger.app`, never
    /// `print`, which never reaches the unified log on a user's device.
    @Test
    func `failure paths log through Logger app without LumiKit`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKit: true))
        #expect(!output.contains("print("))
        #expect(output.contains("import os"))
        #expect(output.contains(
            "Logger.app.error(\"Remote notification registration failed: \\(String(describing: error), privacy: .private)\")"
        ))
        #expect(output.contains(
            "Logger.app.error(\"Failed to create ModelContainer: \\(String(describing: error), privacy: .private)\")"
        ))
        // One shared logger (declared in AppConstants), not one per failure path.
        #expect(!output.contains("Logger(subsystem:"))
    }

    @Test
    func `failure paths log through LMKLogger with LumiKit`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKit: true, lumiKit: true))
        #expect(!output.contains("print("))
        #expect(!output.contains("import os"))
        #expect(output.contains("import LumiKitCore"))
        #expect(output.contains("LMKLogger.error(\"Remote notification registration failed\", error: error, category: LMKLogger.LogCategory.network)"))
        #expect(output.contains("LMKLogger.error(\"Failed to create ModelContainer\", error: error, category: LMKLogger.LogCategory.data)"))
    }

    /// `os` sorts between CoreData and SwiftData, where SwiftFormat's case-insensitive `sortImports` puts it.
    @Test
    func `os import is sorted case-insensitively`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKit: true, notifications: true))
        let imports = output.split(separator: "\n").filter { $0.hasPrefix("import ") }
        #expect(imports == imports.sorted { $0.lowercased() < $1.lowercased() })
    }

    @Test
    func `no os import when nothing logs`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import os"))
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

    /// A tap that launches the app arrives before any screen exists, so a
    /// broadcast would reach no observer; the scene holds and routes it.
    @Test
    func `notification taps go to the scene instead of a broadcast`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(notifications: true))
        #expect(output.contains("let scene = response.targetScene ?? UIApplication.shared.connectedScenes.first"))
        #expect(output.contains("(scene?.delegate as? SceneDelegate)?.handleNotificationResponse(response)"))
        #expect(!output.contains("NotificationCenter.default.post"))
        #expect(!output.contains("userNotificationReceived"))
    }

    @Test
    func `no notification scaffolding without feature`() {
        let output = AppDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import UserNotifications"))
        #expect(!output.contains("UNUserNotificationCenterDelegate"))
    }

    // MARK: - Menu

    /// The View menu exists on every idiom (the Mac and iPadOS 26 menu bars,
    /// keyboard shortcuts elsewhere) and resolves through the responder chain.
    @Test(arguments: [false, true])
    func `tabs add a responder-chain View menu on every idiom`(macCatalyst: Bool) {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: macCatalyst, tabs: twoTabs))
        #expect(output.contains("    override func buildMenu(with builder: any UIMenuBuilder) {"))
        #expect(!output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("action: #selector(MainTabBarController.selectTabFromMenu(_:)),"))
        #expect(output.contains("action: #selector(MainTabBarController.refreshFromMenu(_:)),"))
        #expect(output.contains("propertyList: tab.tag.identifier"))
        #expect(output.contains(
            "builder.insertChild(UIMenu(options: .displayInline, children: tabCommands + [refreshCommand]), atEndOfMenu: .view)"
        ))
        // No broadcast, no top-level menu named after the app.
        #expect(!output.contains("NotificationCenter.default.post"))
        #expect(!output.contains("macMenu"))
        #expect(!output.contains("insertSibling"))
        #expect(!output.contains("UIMenu(title: \"TestApp\""))
    }

    @Test
    func `menu lists each tab with its shortcut position`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(tabs: twoTabs))
        #expect(output.contains("""
                let tabs: [(title: String, tag: TabBarTag)] = [
                    ("Home", .home),
                    ("Settings", .settings),
                ]
        """))
        #expect(output.contains("input: String(index + 1),"))
        #expect(output.contains("title: \"Refresh\","))
    }

    @Test
    func `menu caps tab shortcuts at nine`() {
        let tabs = (1 ... 11).map { TabDefinition(name: "Tab\($0)", icon: "circle") }
        let output = AppDelegateGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("(\"Tab9\", .tab9),"))
        #expect(!output.contains("(\"Tab10\", .tab10),"))
    }

    /// A tab-less app has no menu: its only command would be a Refresh with
    /// nothing to reload.
    @Test(arguments: [false, true])
    func `no menu without tabs`(macCatalyst: Bool) {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: macCatalyst))
        #expect(!output.contains("buildMenu"))
        #expect(!output.contains("UIKeyCommand"))
    }

    /// When localization is on, menu titles read from the catalog, matching
    /// the tab bar, not hardcoded English under a non-English system locale.
    @Test
    func `localized menu reads catalog titles`() {
        let output = AppDelegateGenerator.generate(config: makeConfig(macCatalyst: true, localization: true, tabs: twoTabs))
        #expect(output.contains("(L10n.Tab.home, .home),"))
        #expect(output.contains("(L10n.Tab.settings, .settings),"))
        // Refresh carries an English default, so it resolves on every platform
        // whether or not the catalog has the key.
        #expect(output.contains("title: String(localized: \"menu.refresh\", defaultValue: \"Refresh\", comment: "))
        #expect(!output.contains("title: \"Refresh\""))
        #expect(!output.contains("(\"Home\", .home)"))
    }
}
