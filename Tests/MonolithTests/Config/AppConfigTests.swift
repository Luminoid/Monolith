import Foundation
import Testing
@testable import MonolithLib

struct AppConfigTests {
    private func makeConfig(
        features: Set<AppFeature> = [],
        platforms: Set<Platform> = [.iPhone],
        tabs: [TabDefinition] = []
    ) -> AppConfig {
        AppConfig(
            name: "TestApp",
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

    // MARK: - resolvedFeatures

    @Test
    func `empty features resolve to empty`() {
        let config = makeConfig()
        #expect(config.resolvedFeatures.isEmpty)
    }

    @Test
    func `tabs auto-derived from non-empty tabs array`() {
        let config = makeConfig(tabs: [TabDefinition(name: "Home", icon: "house")])
        #expect(config.resolvedFeatures.contains(.tabs))
    }

    @Test
    func `tabs not derived when tabs array is empty`() {
        let config = makeConfig(features: [.swiftData])
        #expect(!config.resolvedFeatures.contains(.tabs))
    }

    @Test
    func `macCatalyst auto-derived from platform`() {
        let config = makeConfig(platforms: [.iPhone, .macCatalyst])
        #expect(config.resolvedFeatures.contains(.macCatalyst))
    }

    @Test
    func `macCatalyst not derived when platform not selected`() {
        let config = makeConfig(platforms: [.iPhone, .iPad])
        #expect(!config.resolvedFeatures.contains(.macCatalyst))
    }

    @Test
    func `darkMode auto-derived from lumiKit`() {
        let config = makeConfig(features: [.lumiKit])
        #expect(config.resolvedFeatures.contains(.darkMode))
    }

    @Test
    func `darkMode not derived without lumiKit`() {
        let config = makeConfig(features: [.swiftData])
        #expect(!config.resolvedFeatures.contains(.darkMode))
    }

    @Test
    func `explicit features preserved in resolved set`() {
        let config = makeConfig(features: [.swiftData, .combine, .devTooling])
        let resolved = config.resolvedFeatures
        #expect(resolved.contains(.swiftData))
        #expect(resolved.contains(.combine))
        #expect(resolved.contains(.devTooling))
    }

    @Test
    func `all auto-derivations combine correctly`() {
        let config = makeConfig(
            features: [.lumiKit, .swiftData],
            platforms: [.iPhone, .macCatalyst],
            tabs: [TabDefinition(name: "Home", icon: "house")]
        )
        let resolved = config.resolvedFeatures
        #expect(resolved.contains(.tabs))
        #expect(resolved.contains(.macCatalyst))
        #expect(resolved.contains(.darkMode))
        #expect(resolved.contains(.lumiKit))
        #expect(resolved.contains(.swiftData))
    }

    // MARK: - Computed Properties

    @Test
    func `hasTabs checks tabs array, not feature set`() {
        let config = makeConfig(features: [.tabs])
        #expect(!config.hasTabs, "hasTabs should be false when tabs array is empty")
    }

    @Test
    func `hasMacCatalyst checks platforms, not feature set`() {
        let config = makeConfig(features: [.macCatalyst])
        #expect(!config.hasMacCatalyst, "hasMacCatalyst should be false when platform not included")
    }

    @Test
    func `convenience properties match resolved features`() {
        let config = makeConfig(features: [.swiftData, .lottie, .combine, .devTooling, .gitHooks, .localization])
        #expect(config.hasSwiftData)
        #expect(config.hasLottie)
        #expect(config.hasCombine)
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
        #expect(config.hasLocalization)
    }

    @Test
    func `hasSnapKit + hasLookin read from externalPackages, not features`() {
        // SnapKit + LookinServer are no longer AppFeature cases — they come via
        // --use-packages or --external-packages.
        let config = AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary,
            externalPackages: [
                ExternalPackage(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit.git", requirement: "from: \"5.7.0\"", packageName: nil),
                ExternalPackage(name: "LookinServer", url: "https://github.com/QMUI/LookinServer.git", requirement: "from: \"1.2.8\"", packageName: nil),
            ],
            targetDependencies: ["SnapKit", "LookinServer"]
        )
        #expect(config.hasSnapKit)
        #expect(config.hasLookin)
    }

    // MARK: - New feature derivations

    @Test
    func `cloudKitSharing implies cloudKit`() {
        let config = makeConfig(features: [.cloudKitSharing, .swiftData])
        #expect(config.resolvedFeatures.contains(.cloudKit))
        #expect(config.hasCloudKit)
        #expect(config.hasCloudKitSharing)
    }

    @Test
    func `cloudKit without persistence layer defaults to Core Data`() {
        let config = makeConfig(features: [.cloudKit])
        #expect(config.resolvedFeatures.contains(.coreData))
        #expect(config.hasCoreData)
    }

    @Test
    func `cloudKit with SwiftData does not also enable Core Data`() {
        let config = makeConfig(features: [.cloudKit, .swiftData])
        #expect(!config.resolvedFeatures.contains(.coreData))
        #expect(config.hasSwiftData)
    }

    @Test
    func `coreDataAuditHook auto-derived from cloudKit plus persistence plus gitHooks`() {
        let config = makeConfig(features: [.coreData, .cloudKit, .gitHooks])
        #expect(config.resolvedFeatures.contains(.coreDataAuditHook))
        #expect(config.hasCoreDataAuditHook)
    }

    @Test
    func `coreDataAuditHook not derived without gitHooks`() {
        let config = makeConfig(features: [.coreData, .cloudKit])
        #expect(!config.resolvedFeatures.contains(.coreDataAuditHook))
    }

    @Test
    func `coreDataAuditHook not derived without cloudKit`() {
        let config = makeConfig(features: [.coreData, .gitHooks])
        #expect(!config.resolvedFeatures.contains(.coreDataAuditHook))
    }

    @Test
    func `hasCloudKitNotifications mirrors hasCloudKit`() {
        let withCK = makeConfig(features: [.cloudKit, .swiftData])
        #expect(withCK.hasCloudKitNotifications)

        let withoutCK = makeConfig()
        #expect(!withoutCK.hasCloudKitNotifications)
    }

    @Test
    func `app group identifier is derived from bundle ID`() {
        let config = makeConfig()
        #expect(config.appGroupIdentifier == "group.com.test.app")
    }

    @Test
    func `new feature accessors track resolvedFeatures`() {
        let config = makeConfig(features: [
            .notifications, .deepLinks, .spotlight,
            .deferredLaunchWork, .widget, .privacyManifest, .appIconValidation,
        ])
        #expect(config.hasNotifications)
        #expect(config.hasDeepLinks)
        #expect(config.hasSpotlight)
        #expect(config.hasDeferredLaunchWork)
        #expect(config.hasWidget)
        #expect(config.hasPrivacyManifest)
        #expect(config.hasAppIconValidation)
    }

    // MARK: - Deprecation warnings

    @Test
    func `no warnings without legacy features`() {
        let config = makeConfig(features: [.swiftData, .lumiKit])
        #expect(config.deprecationWarnings.isEmpty)
    }

    @Test
    func `rSwift triggers deprecation warning`() {
        let config = makeConfig(features: [.rSwift])
        #expect(config.deprecationWarnings.contains { $0.contains("rSwift") })
    }

    @Test
    func `fastlane triggers deprecation warning`() {
        let config = makeConfig(features: [.fastlane])
        #expect(config.deprecationWarnings.contains { $0.contains("fastlane") })
    }

    // MARK: - External Packages + Target Dependencies

    private func makeConfigWithExternals(
        externalPackages: [ExternalPackage] = [],
        targetDependencies: [String] = []
    ) -> AppConfig {
        AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary,
            externalPackages: externalPackages,
            targetDependencies: targetDependencies
        )
    }

    @Test
    func `validate() is no-op when both lists empty`() throws {
        let config = makeConfigWithExternals()
        try config.validate()    // no throw == pass
    }

    @Test
    func `validate() rejects external package name colliding with app target`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "TestApp", url: "https://example.com/x", requirement: "from: \"0.1.0\"", packageName: nil)],
            targetDependencies: ["TestApp"]
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `validate() rejects external package not consumed by target-deps`() {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "UnusedLib", url: "https://example.com/x", requirement: "from: \"0.1.0\"", packageName: nil)],
            targetDependencies: []
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `validate() accepts consumed external package`() throws {
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["Prism"]
        )
        try config.validate()
    }

    @Test
    func `target-deps without external-packages is allowed (built-in product names)`() throws {
        // Users may pass --target-deps "SnapKit" alongside --features snapKit
        // as a no-op redundancy. The generator de-dupes; validate() permits it.
        let config = makeConfigWithExternals(
            targetDependencies: ["SnapKit"]
        )
        try config.validate()
    }

    @Test
    func `validate() accepts single external + multi-product target-deps (multi-product framework case)`() throws {
        // The Prism/LumiKit case: one external declaration, multiple products linked.
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["PrismCore", "PrismUI"]
        )
        try config.validate()
    }

    @Test
    func `validate() rejects single external with empty target-deps`() {
        // A declared external without any target-deps is dangling.
        let config = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: []
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `validate() accepts multi-external + multi-product target-deps (relaxed routing)`() throws {
        // Two declared externals + target-deps that reference products from each.
        // The generator does best-effort routing — direct name match wins; ambiguous
        // products fall through to single-remaining or product=package fallback.
        let config = makeConfigWithExternals(
            externalPackages: [
                ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil),
                ExternalPackage(name: "LumiKit", url: "https://github.com/luminoid/LumiKit", requirement: "from: \"0.8.0\"", packageName: nil),
            ],
            targetDependencies: ["PrismCore", "PrismUI", "LumiKitUI"]
        )
        try config.validate()
    }

    @Test
    func `validate() rejects multiple externals with empty target-deps`() {
        // All externals declared but no target-deps — the packages: block would
        // emit unused entries.
        let config = makeConfigWithExternals(
            externalPackages: [
                ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil),
                ExternalPackage(name: "Causeway", url: "https://github.com/luminoid/Causeway", requirement: "from: \"0.1.0\"", packageName: nil),
            ],
            targetDependencies: []
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `local-path external package parses and validates`() throws {
        let parsed = try ExternalPackage.parse("Prism=/Users/me/Projects/Prism")
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "Prism")
        #expect(parsed[0].url == "/Users/me/Projects/Prism")
        #expect(parsed[0].requirement.isEmpty)
        #expect(parsed[0].isLocalPath == true)

        // Relative path also works.
        let relative = try ExternalPackage.parse("LumiKit=../LumiKit")
        #expect(relative[0].url == "../LumiKit")
        #expect(relative[0].isLocalPath == true)

        // Path form with explicit packageName.
        let withName = try ExternalPackage.parse("PrismCore=/abs/Prism:Prism")
        #expect(withName[0].url == "/abs/Prism")
        #expect(withName[0].packageName == "Prism")
        #expect(withName[0].isLocalPath == true)
    }

    @Test
    func `URL-form external package still parses correctly after path-form addition`() throws {
        // Regression check: URL form must keep working unchanged.
        let parsed = try ExternalPackage.parse("Prism=https://github.com/luminoid/Prism:from: \"0.3.0\"")
        #expect(parsed.count == 1)
        #expect(parsed[0].url == "https://github.com/luminoid/Prism")
        #expect(parsed[0].requirement == "from: \"0.3.0\"")
        #expect(parsed[0].isLocalPath == false)
    }

    @Test
    func `Codable round-trips externalPackages and targetDependencies`() throws {
        let original = makeConfigWithExternals(
            externalPackages: [ExternalPackage(name: "Prism", url: "https://github.com/luminoid/Prism", requirement: "from: \"0.3.0\"", packageName: nil)],
            targetDependencies: ["Prism", "PrismUI"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.externalPackages.count == 1)
        #expect(decoded.externalPackages.first?.name == "Prism")
        #expect(decoded.targetDependencies == ["Prism", "PrismUI"])
    }

    @Test
    func `Codable decoding tolerates missing external-package fields (backwards compat)`() throws {
        // Legacy saved config without the new fields should decode with empty defaults.
        let legacyJSON = """
        {
            "name": "TestApp",
            "bundleID": "com.test.app",
            "deploymentTarget": "18.0",
            "platforms": ["iPhone"],
            "projectSystem": "xcodeProj",
            "tabs": [],
            "primaryColor": "#007AFF",
            "features": [],
            "author": "Test",
            "licenseType": "proprietary"
        }
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.externalPackages.isEmpty)
        #expect(decoded.targetDependencies.isEmpty)
    }

    // MARK: - --use-packages registry

    @Test
    func `parseUsePackages resolves bare identifier to registry default version`() throws {
        let parsed = try ExternalPackage.parseUsePackages("SnapKit")
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "SnapKit")
        #expect(parsed[0].url == "https://github.com/SnapKit/SnapKit.git")
        #expect(parsed[0].requirement == "from: \"\(DependencyVersion.snapKit)\"")
        #expect(parsed[0].isLocalPath == false)
    }

    @Test
    func `parseUsePackages honors version override`() throws {
        let parsed = try ExternalPackage.parseUsePackages("Lottie:5.0.0")
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "Lottie")
        #expect(parsed[0].requirement == "from: \"5.0.0\"")
    }

    @Test
    func `parseUsePackages handles comma-separated multi-identifier`() throws {
        let parsed = try ExternalPackage.parseUsePackages("SnapKit,LookinServer:1.3.0")
        #expect(parsed.count == 2)
        #expect(parsed[0].name == "SnapKit")
        #expect(parsed[1].name == "LookinServer")
        #expect(parsed[1].requirement == "from: \"1.3.0\"")
    }

    @Test
    func `parseUsePackages throws helpful error for unknown identifier`() {
        #expect(throws: ExternalPackage.UsePackagesParseError.self) {
            try ExternalPackage.parseUsePackages("UnknownLib")
        }
    }

    @Test
    func `parseUsePackages returns empty for nil and empty input`() throws {
        #expect(try ExternalPackage.parseUsePackages(nil).isEmpty)
        #expect(try ExternalPackage.parseUsePackages("").isEmpty)
    }

    @Test
    func `KnownPackages registry exposes the expected built-ins`() {
        let identifiers = Set(KnownPackages.allIdentifiers)
        #expect(identifiers == ["SnapKit", "Lottie", "LookinServer"])
    }

    @Test
    func `KnownPackages LookinServer carries iOS platform conditional`() {
        let entry = KnownPackages.registry["LookinServer"]
        #expect(entry?.platforms == ["iOS"])
    }

    @Test
    func `KnownPackages SnapKit + Lottie have no platform conditional`() {
        #expect(KnownPackages.registry["SnapKit"]?.platforms == nil)
        #expect(KnownPackages.registry["Lottie"]?.platforms == nil)
    }

    @Test
    func `AppFeature.deprecatedPackageFeatureNames covers snapKit + lookin`() {
        #expect(AppFeature.deprecatedPackageFeatureNames == ["snapKit", "lookin"])
    }
}

// MARK: - Platform displayName

struct PlatformDisplayNameTests {
    @Test
    func `all platforms have display names`() {
        #expect(Platform.iPhone.displayName == "iPhone")
        #expect(Platform.iPad.displayName == "iPad")
        #expect(Platform.macCatalyst.displayName == "Mac Catalyst")
    }

    @Test
    func `all cases have non-empty display names`() {
        for platform in Platform.allCases {
            #expect(!platform.displayName.isEmpty)
        }
    }
}

// MARK: - ProjectSystem displayName

struct ProjectSystemDisplayNameTests {
    @Test
    func `all project systems have display names`() {
        #expect(ProjectSystem.xcodeProj.displayName == "Xcode Project (recommended)")
        #expect(ProjectSystem.xcodeGen.displayName == "XcodeGen (keeps project.yml)")
        #expect(ProjectSystem.spm.displayName == "SPM (Swift Package Manager)")
    }
}

// MARK: - PackagePlatform

struct PackagePlatformTests {
    @Test
    func `all display names`() {
        #expect(PackagePlatform.iOS.displayName == "iOS")
        #expect(PackagePlatform.macOS.displayName == "macOS")
        #expect(PackagePlatform.macCatalyst.displayName == "Mac Catalyst")
        #expect(PackagePlatform.watchOS.displayName == "watchOS")
        #expect(PackagePlatform.tvOS.displayName == "tvOS")
        #expect(PackagePlatform.visionOS.displayName == "visionOS")
    }

    @Test
    func `all platforms have default versions`() {
        for platform in PackagePlatform.allCases {
            #expect(Validators.validatePlatformVersion(platform.defaultVersion),
                    "\(platform.displayName) default version '\(platform.defaultVersion)' should be valid")
        }
    }

    @Test
    func `platformName matches rawValue`() {
        for platform in PackagePlatform.allCases {
            #expect(platform.platformName == platform.rawValue)
        }
    }
}
