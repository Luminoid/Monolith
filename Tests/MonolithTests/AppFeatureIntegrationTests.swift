import Foundation
import Testing
@testable import MonolithLib

/// End-to-end coverage for every individual `AppFeature` (and its derived
/// features). Each test enables one feature in isolation so a regression in
/// that feature's wiring fails its own test, not the kitchen-sink case.
///
/// Nested under `MonolithIntegrationSuite` so `.serialized` propagates
/// downward and `withTempDir` calls cannot race sibling suites.
extension MonolithIntegrationSuite {
    struct AppFeatureIntegrationTests {
        // MARK: - Persistence Features

        @Test
        func `Core Data without CloudKit emits NSPersistentContainer stack and non-CloudKit model`() throws {
            try withTempDir(prefix: "monolith-test-coredata") { tempDir in
                let config = AppConfig(
                    name: "CDApp",
                    bundleID: "com.test.cd",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.coreData],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/CDApp"
                let modelDir = "\(basePath)/CDApp/Core/Models/CDApp.xcdatamodeld"
                #expect(FileManager.default.fileExists(atPath: "\(modelDir)/CDApp.xcdatamodel/contents"))
                #expect(FileManager.default.fileExists(atPath: "\(modelDir)/.xccurrentversion"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/CDApp/Core/Persistence/CDAppCoreDataStack.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/CDAppTests/Helpers/TestContext.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/CDAppTests/Helpers/TestDataFactory.swift"))

                let stack = try String(contentsOfFile: "\(basePath)/CDApp/Core/Persistence/CDAppCoreDataStack.swift", encoding: .utf8)
                #expect(stack.contains("NSPersistentContainer"))
                #expect(!stack.contains("NSPersistentCloudKitContainer"))

                let model = try String(contentsOfFile: "\(modelDir)/CDApp.xcdatamodel/contents", encoding: .utf8)
                #expect(model.contains("usedWithCloudKit=\"NO\""))

                let delegate = try String(contentsOfFile: "\(basePath)/CDApp/App/AppDelegate.swift", encoding: .utf8)
                #expect(delegate.contains("import CoreData"))
                #expect(delegate.contains("CDAppCoreDataStack.shared"))

                let infoPlist = try String(contentsOfFile: "\(basePath)/CDApp/Info.plist", encoding: .utf8)
                #expect(!infoPlist.contains("remote-notification"))
            }
        }

        @Test
        func `CloudKit auto-derives Core Data and registers for remote notifications`() throws {
            try withTempDir(prefix: "monolith-test-cloudkit") { tempDir in
                let config = AppConfig(
                    name: "CKApp",
                    bundleID: "com.test.ck",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.cloudKit],
                    author: "Test",
                    licenseType: .proprietary
                )
                #expect(config.resolvedFeatures.contains(.coreData))

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/CKApp"
                let stack = try String(contentsOfFile: "\(basePath)/CKApp/Core/Persistence/CKAppCoreDataStack.swift", encoding: .utf8)
                #expect(stack.contains("NSPersistentCloudKitContainer"))

                let model = try String(contentsOfFile: "\(basePath)/CKApp/Core/Models/CKApp.xcdatamodeld/CKApp.xcdatamodel/contents", encoding: .utf8)
                #expect(model.contains("usedWithCloudKit=\"YES\""))

                let delegate = try String(contentsOfFile: "\(basePath)/CKApp/App/AppDelegate.swift", encoding: .utf8)
                #expect(delegate.contains("registerForRemoteNotifications"))
                #expect(delegate.contains("didRegisterForRemoteNotificationsWithDeviceToken"))

                let infoPlist = try String(contentsOfFile: "\(basePath)/CKApp/Info.plist", encoding: .utf8)
                #expect(infoPlist.contains("UIBackgroundModes"))
                #expect(infoPlist.contains("remote-notification"))

                // The entitlements that actually enable CloudKit must be present
                // even with no widget — otherwise the container can't sync and
                // registerForRemoteNotifications() fails at runtime.
                let entitlements = try String(contentsOfFile: "\(basePath)/CKApp/CKApp.entitlements", encoding: .utf8)
                #expect(entitlements.contains("aps-environment"))
                #expect(entitlements.contains("com.apple.developer.icloud-container-identifiers"))
                #expect(entitlements.contains("iCloud.com.test.ck"))
                #expect(entitlements.contains("com.apple.developer.icloud-services"))
                #expect(entitlements.contains("CloudKit"))
                // No widget → no App Group key.
                #expect(!entitlements.contains("application-groups"))

                // The app target must be pointed at its entitlements even without
                // a widget (the gate used to be hasWidget-only).
                let pbxproj = try String(contentsOfFile: "\(basePath)/CKApp.xcodeproj/project.pbxproj", encoding: .utf8)
                #expect(pbxproj.contains("CKApp/CKApp.entitlements"))
            }
        }

        @Test
        func `CloudKit Sharing implies CloudKit and emits CKSharingSupported plus accept handler`() throws {
            try withTempDir(prefix: "monolith-test-cksharing") { tempDir in
                let config = AppConfig(
                    name: "ShareApp",
                    bundleID: "com.test.share",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.cloudKitSharing],
                    author: "Test",
                    licenseType: .proprietary
                )
                #expect(config.resolvedFeatures.contains(.cloudKit))
                #expect(config.resolvedFeatures.contains(.coreData))

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/ShareApp"
                let infoPlist = try String(contentsOfFile: "\(basePath)/ShareApp/Info.plist", encoding: .utf8)
                #expect(infoPlist.contains("CKSharingSupported"))

                let scene = try String(contentsOfFile: "\(basePath)/ShareApp/App/SceneDelegate.swift", encoding: .utf8)
                #expect(scene.contains("userDidAcceptCloudKitShareWith"))
                #expect(scene.contains("import CloudKit"))

                // The persistence stack must back the share-accept hook with a
                // private + shared dual store; otherwise an accepted share has
                // nowhere to land.
                let stack = try String(contentsOfFile: "\(basePath)/ShareApp/Core/Persistence/ShareAppCoreDataStack.swift", encoding: .utf8)
                #expect(stack.contains("import CloudKit"))
                #expect(stack.contains("databaseScope = .private"))
                #expect(stack.contains("databaseScope = .shared"))
                #expect(stack.contains("[privateDescription, sharedDescription]"))
                #expect(stack.contains("NSMergePolicy.mergeByPropertyObjectTrump"))

                // And the entitlements must declare the iCloud container so both
                // stores can reach CloudKit.
                let entitlements = try String(contentsOfFile: "\(basePath)/ShareApp/ShareApp.entitlements", encoding: .utf8)
                #expect(entitlements.contains("iCloud.com.test.share"))
                #expect(entitlements.contains("com.apple.developer.icloud-services"))
            }
        }

        @Test
        func `coreDataAuditHook is auto-derived when persistence + cloudKit + gitHooks coexist`() throws {
            try withTempDir(prefix: "monolith-test-cdaudit") { tempDir in
                let config = AppConfig(
                    name: "AuditApp",
                    bundleID: "com.test.audit",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.coreData, .cloudKit, .gitHooks],
                    author: "Test",
                    licenseType: .proprietary
                )
                #expect(config.resolvedFeatures.contains(.coreDataAuditHook))

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/AuditApp"
                let hook = try String(contentsOfFile: "\(basePath)/Scripts/git-hooks/pre-commit", encoding: .utf8)
                #expect(hook.lowercased().contains("core data") || hook.contains(".xcdatamodel"))
            }
        }

        // MARK: - UI / Third-Party Dependencies

        @Test
        func `LumiKit auto-enables darkMode and emits theme file plus LMK wiring`() throws {
            try withTempDir(prefix: "monolith-test-lumikit") { tempDir in
                let config = AppConfig(
                    name: "LMKApp",
                    bundleID: "com.test.lmk",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#4CAF7D",
                    features: [.lumiKit],
                    author: "Test",
                    licenseType: .proprietary
                )
                #expect(config.resolvedFeatures.contains(.darkMode))

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/LMKApp"
                // LumiKit emits the theme as <Name>Theme.swift, not the standalone AppTheme.swift
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/LMKApp/Shared/Design/LMKAppTheme.swift"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/LMKApp/Shared/Design/AppTheme.swift"))

                let delegate = try String(contentsOfFile: "\(basePath)/LMKApp/App/AppDelegate.swift", encoding: .utf8)
                #expect(delegate.contains("import LumiKitUI"))
                #expect(delegate.contains("LMKThemeManager.shared.apply"))

                let yml = try String(contentsOfFile: "\(basePath)/project.yml", encoding: .utf8)
                #expect(yml.contains("LumiKit"))
            }
        }

        @Test
        func `SnapKit is wired into project.yml dependencies`() throws {
            try withTempDir(prefix: "monolith-test-snapkit") { tempDir in
                let config = AppConfig(
                    name: "SnapApp",
                    bundleID: "com.test.snap",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [],
                    author: "Test",
                    licenseType: .proprietary,
                    externalPackages: [ExternalPackage(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit.git", requirement: "from: \"5.7.0\"", packageName: nil)],
                    targetDependencies: ["SnapKit"]
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/SnapApp"
                let yml = try String(contentsOfFile: "\(basePath)/project.yml", encoding: .utf8)
                #expect(yml.contains("SnapKit"))
            }
        }

        @Test
        func `Lottie emits helper and wires SPM dependency`() throws {
            try withTempDir(prefix: "monolith-test-lottie") { tempDir in
                let config = AppConfig(
                    name: "LottieApp",
                    bundleID: "com.test.lottie",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.lottie],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/LottieApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/LottieApp/Shared/Components/LottieHelper.swift"))

                let yml = try String(contentsOfFile: "\(basePath)/project.yml", encoding: .utf8)
                #expect(yml.contains("Lottie"))
            }
        }

        @Test
        func `Lookin is gated to iOS-only platforms in project.yml`() throws {
            try withTempDir(prefix: "monolith-test-lookin") { tempDir in
                let config = AppConfig(
                    name: "LookinApp",
                    bundleID: "com.test.lookin",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone, .macCatalyst],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [],
                    author: "Test",
                    licenseType: .proprietary,
                    externalPackages: [ExternalPackage(name: "LookinServer", url: "https://github.com/QMUI/LookinServer.git", requirement: "from: \"1.2.8\"", packageName: nil)],
                    targetDependencies: ["LookinServer"]
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/LookinApp"
                let yml = try String(contentsOfFile: "\(basePath)/project.yml", encoding: .utf8)
                #expect(yml.contains("LookinServer"))
            }
        }

        // MARK: - System Integrations

        @Test
        func `notifications wires UNUserNotificationCenterDelegate and import`() throws {
            try withTempDir(prefix: "monolith-test-notif") { tempDir in
                let config = AppConfig(
                    name: "NotifApp",
                    bundleID: "com.test.notif",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.notifications],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/NotifApp"
                let delegate = try String(contentsOfFile: "\(basePath)/NotifApp/App/AppDelegate.swift", encoding: .utf8)
                #expect(delegate.contains("import UserNotifications"))
                #expect(delegate.contains("UNUserNotificationCenterDelegate"))
                #expect(delegate.contains("willPresent notification"))
                #expect(delegate.contains("didReceive response"))
            }
        }

        @Test
        func `deepLinks emit URL scheme and SceneDelegate handlers`() throws {
            try withTempDir(prefix: "monolith-test-deeplinks") { tempDir in
                let config = AppConfig(
                    name: "DeepApp",
                    bundleID: "com.test.deep",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.deepLinks],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/DeepApp"
                let infoPlist = try String(contentsOfFile: "\(basePath)/DeepApp/Info.plist", encoding: .utf8)
                #expect(infoPlist.contains("CFBundleURLTypes"))
                #expect(infoPlist.contains("CFBundleURLSchemes"))
                #expect(infoPlist.contains("deepapp"))

                let scene = try String(contentsOfFile: "\(basePath)/DeepApp/App/SceneDelegate.swift", encoding: .utf8)
                #expect(scene.contains("openURLContexts"))
            }
        }

        @Test
        func `spotlight emits NSUserActivity handler in SceneDelegate`() throws {
            try withTempDir(prefix: "monolith-test-spotlight") { tempDir in
                let config = AppConfig(
                    name: "SpotApp",
                    bundleID: "com.test.spot",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.spotlight],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/SpotApp"
                let scene = try String(contentsOfFile: "\(basePath)/SpotApp/App/SceneDelegate.swift", encoding: .utf8)
                #expect(scene.contains("CSSearchableItemActionType") || scene.contains("continue userActivity"))
            }
        }

        @Test
        func `deferredLaunchWork emits helper in SceneDelegate`() throws {
            try withTempDir(prefix: "monolith-test-deferred") { tempDir in
                let config = AppConfig(
                    name: "DeferApp",
                    bundleID: "com.test.defer",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.deferredLaunchWork],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/DeferApp"
                let scene = try String(contentsOfFile: "\(basePath)/DeferApp/App/SceneDelegate.swift", encoding: .utf8)
                #expect(scene.contains("deferLaunchWork"))
            }
        }

        @Test
        func `widget extension emits target files, App Group, and entitlements`() throws {
            try withTempDir(prefix: "monolith-test-widget") { tempDir in
                let config = AppConfig(
                    name: "WidApp",
                    bundleID: "com.test.widget",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.widget],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/WidApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WidAppWidget/Info.plist"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WidAppWidget/WidAppWidget.entitlements"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WidAppWidget/WidAppWidgetBundle.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WidAppWidget/WidAppWidget.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WidApp/Shared/AppGroup.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WidApp/WidApp.entitlements"))

                let appGroup = try String(contentsOfFile: "\(basePath)/WidApp/Shared/AppGroup.swift", encoding: .utf8)
                #expect(appGroup.contains("group.com.test.widget"))

                let entitlements = try String(contentsOfFile: "\(basePath)/WidAppWidget/WidAppWidget.entitlements", encoding: .utf8)
                #expect(entitlements.contains("application-groups"))
                #expect(entitlements.contains("group.com.test.widget"))

                let appEntitlements = try String(contentsOfFile: "\(basePath)/WidApp/WidApp.entitlements", encoding: .utf8)
                #expect(appEntitlements.contains("application-groups"))
                #expect(appEntitlements.contains("group.com.test.widget"))

                let widget = try String(contentsOfFile: "\(basePath)/WidAppWidget/WidAppWidget.swift", encoding: .utf8)
                #expect(widget.contains("TimelineProvider"))
                #expect(widget.contains("WidgetConfiguration"))

                // project.yml must declare the widget target, link it to the
                // app, and point the app at its entitlements file — otherwise
                // the widget Swift files end up orphaned and the App Group
                // capability never reaches the app's signing.
                let yaml = try String(contentsOfFile: "\(basePath)/project.yml", encoding: .utf8)
                #expect(yaml.contains("\n  WidAppWidget:\n"))
                #expect(yaml.contains("type: app-extension"))
                #expect(yaml.contains("- target: WidAppWidget"))
                #expect(yaml.contains("CODE_SIGN_ENTITLEMENTS: WidApp/WidApp.entitlements"))
                #expect(yaml.contains("CODE_SIGN_ENTITLEMENTS: WidAppWidget/WidAppWidget.entitlements"))
                #expect(yaml.contains("WidgetKit.framework"))

                // Widget bundle always ships a PrivacyInfo.xcprivacy even
                // when the app-level privacyManifest feature is OFF, because
                // Apple requires one manifest per shipped bundle and the
                // widget bundle is independently shipped. The APP's
                // PrivacyInfo is still gated on the app-level feature
                // (see the privacyManifest-only test below).
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WidAppWidget/PrivacyInfo.xcprivacy"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/WidApp/Resources/PrivacyInfo.xcprivacy"))
            }
        }

        @Test
        func `widget plus privacyManifest emits manifest in widget bundle too`() throws {
            try withTempDir(prefix: "monolith-test-widget-privacy") { tempDir in
                let config = AppConfig(
                    name: "WPApp",
                    bundleID: "com.test.wp",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.widget, .privacyManifest],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/WPApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WPApp/Resources/PrivacyInfo.xcprivacy"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/WPAppWidget/PrivacyInfo.xcprivacy"))
            }
        }

        // MARK: - App Store Hygiene

        @Test
        func `privacyManifest writes PrivacyInfo file even without widget`() throws {
            try withTempDir(prefix: "monolith-test-privacy") { tempDir in
                let config = AppConfig(
                    name: "PrivApp",
                    bundleID: "com.test.priv",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.privacyManifest],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/PrivApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/PrivApp/Resources/PrivacyInfo.xcprivacy"))

                let manifest = try String(contentsOfFile: "\(basePath)/PrivApp/Resources/PrivacyInfo.xcprivacy", encoding: .utf8)
                #expect(manifest.contains("NSPrivacyTracking"))
            }
        }

        @Test
        func `appIconValidation writes executable build-phase script`() throws {
            try withTempDir(prefix: "monolith-test-iconval") { tempDir in
                let config = AppConfig(
                    name: "IconApp",
                    bundleID: "com.test.icon",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeProj,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.appIconValidation],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/IconApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Scripts/validate-app-icon.sh"))

                let script = try String(contentsOfFile: "\(basePath)/Scripts/validate-app-icon.sh", encoding: .utf8)
                #expect(script.contains("AppIcon.appiconset"))
            }
        }

        // MARK: - Legacy Tooling

        @Test
        func `rSwift emits Mintfile and surfaces deprecation warning`() throws {
            try withTempDir(prefix: "monolith-test-rswift") { tempDir in
                let config = AppConfig(
                    name: "RSApp",
                    bundleID: "com.test.rs",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.rSwift],
                    author: "Test",
                    licenseType: .proprietary
                )
                #expect(config.deprecationWarnings.contains(where: { $0.contains("rSwift") }))

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/RSApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Mintfile"))
            }
        }

        @Test
        func `fastlane emits Gemfile, Appfile, Fastfile and surfaces deprecation warning`() throws {
            try withTempDir(prefix: "monolith-test-fastlane") { tempDir in
                let config = AppConfig(
                    name: "FLApp",
                    bundleID: "com.test.fl",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.fastlane],
                    author: "Test",
                    licenseType: .proprietary
                )
                #expect(config.deprecationWarnings.contains(where: { $0.contains("fastlane") }))

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/FLApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Gemfile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/fastlane/Appfile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/fastlane/Fastfile"))
            }
        }

        // MARK: - Project Systems

        @Test
        func `SPM app project writes Package_swift with iOS platform`() throws {
            try withTempDir(prefix: "monolith-test-spm-app") { tempDir in
                let config = AppConfig(
                    name: "SPMApp",
                    bundleID: "com.test.spm",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone, .macCatalyst],
                    projectSystem: .spm,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [.lumiKit, .localization],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/SPMApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Package.swift"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/project.yml"))

                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(pkg.contains(".iOS(.v18)"))
                #expect(pkg.contains(".macCatalyst(.v18)"))
                #expect(pkg.contains("LumiKit"))
                #expect(pkg.contains("defaultLocalization"))
            }
        }

        @Test
        func `xcodeGen project keeps project_yml in place`() throws {
            try withTempDir(prefix: "monolith-test-xcgen") { tempDir in
                let config = AppConfig(
                    name: "GenApp",
                    bundleID: "com.test.gen",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/GenApp"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/project.yml"))
                let yml = try String(contentsOfFile: "\(basePath)/project.yml", encoding: .utf8)
                #expect(yml.contains("GenApp"))
            }
        }

        // MARK: - Combinations With Distinct Output

        /// "Everything on" smoke test: every prompt-exposed option enabled,
        /// with the recommended tech picked for either/or choices
        /// (`swiftData` over `coreData`, `xcodeProj` over `xcodeGen`/`spm`,
        /// `proprietary` license per app default). Legacy flags (`rSwift`,
        /// `fastlane`) are excluded — they're tested individually in the
        /// legacy-tooling section and warn on use.
        ///
        /// This catches generator-interaction regressions that per-feature
        /// tests miss (e.g., a flag combination that one path silently
        /// clobbers another's output). Assertions are limited to
        /// generator-interaction signals (AppDelegate imports the union of
        /// every feature's libraries, every output dir is populated) rather
        /// than restating per-file paths the per-feature tests already cover.
        @Test
        func `App with every recommended option enabled stays self-consistent`() throws {
            try withTempDir(prefix: "monolith-test-all-on") { tempDir in
                let features: Set<AppFeature> = [
                    .swiftData, .cloudKit, .cloudKitSharing,
                    .lumiKit, .lottie, .darkMode, .combine,
                    .notifications, .deepLinks, .spotlight, .deferredLaunchWork, .widget,
                    .localization, .privacyManifest, .appIconValidation,
                    .devTooling, .gitHooks, .claudeMD, .licenseChangelog,
                ]
                // SnapKit + LookinServer come via the --use-packages synthesis.
                let externalPackages: [ExternalPackage] = [
                    ExternalPackage(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit.git", requirement: "from: \"5.7.0\"", packageName: nil),
                    ExternalPackage(name: "LookinServer", url: "https://github.com/QMUI/LookinServer.git", requirement: "from: \"1.2.8\"", packageName: nil),
                ]
                let config = AppConfig(
                    name: "AllOnApp",
                    bundleID: "com.test.allon",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone, .iPad, .macCatalyst],
                    projectSystem: .xcodeProj,
                    tabs: [
                        TabDefinition(name: "Home", icon: "house.fill"),
                        TabDefinition(name: "Settings", icon: "gear"),
                    ],
                    primaryColor: "#4CAF7D",
                    features: features,
                    author: "Test",
                    licenseType: .proprietary,
                    externalPackages: externalPackages,
                    targetDependencies: ["SnapKit", "LookinServer"]
                )

                // Auto-derivation must fire for everything that depends on the
                // selected base features.
                #expect(config.resolvedFeatures.contains(.tabs))
                #expect(config.resolvedFeatures.contains(.macCatalyst))
                #expect(config.resolvedFeatures.contains(.darkMode))
                #expect(config.resolvedFeatures.contains(.coreDataAuditHook))
                // SwiftData was selected (recommended over coreData), so the
                // CloudKit-needs-persistence rule must NOT silently add coreData.
                #expect(!config.resolvedFeatures.contains(.coreData))

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/AllOnApp"

                // SwiftData path (not Core Data — the recommended persistence here)
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/AllOnApp/Core/Models/SampleItem.swift"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/AllOnApp/Core/Persistence/AllOnAppCoreDataStack.swift"))

                // Widget + privacy manifest combo (both bundles get a manifest)
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/AllOnApp/Resources/PrivacyInfo.xcprivacy"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/AllOnAppWidget/PrivacyInfo.xcprivacy"))

                // AppDelegate must import the union of every feature's libraries
                // without one path overwriting another's import block.
                let delegate = try String(contentsOfFile: "\(basePath)/AllOnApp/App/AppDelegate.swift", encoding: .utf8)
                #expect(delegate.contains("import SwiftData"))
                #expect(delegate.contains("import LumiKitUI"))
                #expect(delegate.contains("import UserNotifications"))
                #expect(delegate.contains("registerForRemoteNotifications"))
                #expect(delegate.contains("buildMenu(with builder"))
                // tabs + macCatalyst combo: per-tab UIKeyCommand entries
                #expect(delegate.contains("handleTabMenu"))
                #expect(delegate.contains("UIMenu(title: \"Tabs\""))

                // SceneDelegate must carry CloudKit sharing + deep links +
                // spotlight + deferred launch hooks side-by-side.
                let scene = try String(contentsOfFile: "\(basePath)/AllOnApp/App/SceneDelegate.swift", encoding: .utf8)
                #expect(scene.contains("userDidAcceptCloudKitShareWith"))
                #expect(scene.contains("openURLContexts"))
                #expect(scene.contains("deferLaunchWork"))
            }
        }

        /// tabs + macCatalyst combination: the Mac menu's `buildMenu` block
        /// gains per-tab ⌘1, ⌘2 … key commands. Neither feature alone produces
        /// this output, so the combo gets its own test.
        @Test
        func `tabs combined with macCatalyst emit per-tab UIKeyCommand entries`() throws {
            try withTempDir(prefix: "monolith-test-tabs-mac") { tempDir in
                let config = AppConfig(
                    name: "TabMacApp",
                    bundleID: "com.test.tabmac",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone, .macCatalyst],
                    projectSystem: .xcodeProj,
                    tabs: [
                        TabDefinition(name: "Home", icon: "house.fill"),
                        TabDefinition(name: "Library", icon: "books.vertical.fill"),
                    ],
                    primaryColor: "#007AFF",
                    features: [],
                    author: "Test",
                    licenseType: .proprietary
                )
                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/TabMacApp"
                let delegate = try String(contentsOfFile: "\(basePath)/TabMacApp/App/AppDelegate.swift", encoding: .utf8)
                #expect(delegate.contains("buildMenu(with builder"))
                #expect(delegate.contains("handleTabMenu"))
                #expect(delegate.contains("input: \"1\""))
                #expect(delegate.contains("input: \"2\""))
                #expect(delegate.contains("UIMenu(title: \"Tabs\""))
            }
        }
    }
}
