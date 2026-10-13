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
                ExternalPackage(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit.git", requirement: "from: \"6.0.0\"", packageName: nil),
                ExternalPackage(name: "LookinServer", url: "https://github.com/QMUI/LookinServer.git", requirement: "from: \"1.2.8\"", packageName: nil),
            ],
            targetDependencies: ["SnapKit", "LookinServer"]
        )
        #expect(config.hasSnapKit)
        #expect(config.hasLookin)
    }

    @Test
    func `hasSnapKit is true when lumiKit feature is set (transitive)`() {
        // LumiKitUI declares SnapKit as a direct SPM dependency, so apps that
        // link LumiKitUI can import SnapKit without an explicit --use-packages.
        // Without this, the ViewController generator falls back to bare
        // NSLayoutConstraint, violating the workspace SnapKit rule.
        let config = makeConfig(features: [.lumiKit])
        #expect(config.hasSnapKit)
    }

    @Test
    func `hasSnapKit is false when neither lumiKit nor SnapKit package is set`() {
        let config = makeConfig(features: [])
        #expect(!config.hasSnapKit)
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
        targetDependencies: [String] = [],
        features: Set<AppFeature> = []
    ) -> AppConfig {
        AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary,
            externalPackages: externalPackages,
            targetDependencies: targetDependencies
        )
    }

    private func external(_ name: String, packageName: String? = nil) -> ExternalPackage {
        ExternalPackage(name: name, url: "https://example.com/\(name).git", requirement: "from: \"0.1.0\"", packageName: packageName)
    }

    @Test
    func `validate() is no-op when both lists empty`() throws {
        let config = makeConfigWithExternals()
        try config.validate() // no throw == pass
    }

    @Test
    func `validate() rejects external package name colliding with app target`() {
        let config = makeConfigWithExternals(
            externalPackages: [external("TestApp")],
            targetDependencies: ["TestApp"]
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `validate() rejects external package not consumed by target-deps`() {
        let config = makeConfigWithExternals(
            externalPackages: [external("UnusedLib")],
            targetDependencies: []
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `validate() accepts consumed external package`() throws {
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg")],
            targetDependencies: ["ExtPkg"]
        )
        try config.validate()
    }

    /// Regression: a registry product nothing wires emitted `- package: SnapKit`
    /// with no matching `packages:` entry.
    @Test
    func `target-deps naming an unwired registry product points at the wiring flag`() {
        let config = makeConfigWithExternals(targetDependencies: ["SnapKit"])
        let error = #expect(throws: AppConfigError.self) { try config.validate() }
        if case let .unwiredKnownProduct(dep, hint) = error {
            #expect(dep == "SnapKit")
            #expect(hint.contains("--use-packages SnapKit"))
        } else {
            Issue.record("Expected .unwiredKnownProduct, got \(String(describing: error))")
        }
    }

    @Test
    func `target-deps naming a product its --use-packages entry wires is accepted`() throws {
        let snapKit = try ExternalPackage.parseUsePackages("SnapKit")
        try makeConfigWithExternals(externalPackages: snapKit, targetDependencies: ["SnapKit"]).validate()
    }

    @Test
    func `target-deps may name products the features wire`() throws {
        try makeConfigWithExternals(targetDependencies: ["LumiKitCore", "LumiKitUI"], features: [.lumiKit]).validate()
        try makeConfigWithExternals(targetDependencies: ["Lottie"], features: [.lottie]).validate()

        let error = #expect(throws: AppConfigError.self) {
            try makeConfigWithExternals(targetDependencies: ["LumiKitUI"]).validate()
        }
        if case let .unwiredKnownProduct(_, hint) = error {
            #expect(hint.contains("--features lumiKit"))
        } else {
            Issue.record("Expected .unwiredKnownProduct, got \(String(describing: error))")
        }
    }

    /// Regression: an unknown product passed validation and failed in xcodebuild.
    @Test
    func `target-deps naming an unknown product is rejected`() {
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg"), external("OtherPkg")],
            targetDependencies: ["ExtPkg", "OtherPkg", "Mystery"]
        )
        let error = #expect(throws: AppConfigError.self) { try config.validate() }
        if case let .unknownTargetDependency(dep) = error {
            #expect(dep == "Mystery")
        } else {
            Issue.record("Expected .unknownTargetDependency, got \(String(describing: error))")
        }
    }

    @Test
    func `target-deps catches the bare LumiKit package name`() {
        let error = #expect(throws: AppConfigError.self) {
            try makeConfigWithExternals(targetDependencies: ["LumiKit"], features: [.lumiKit]).validate()
        }
        if case let .misspelledProduct(dep, suggestions) = error {
            #expect(dep == "LumiKit")
            #expect(suggestions.contains("LumiKitUI"))
        } else {
            Issue.record("Expected .misspelledProduct, got \(String(describing: error))")
        }
        #expect(error?.description.contains("Depend on a product") == true)
    }

    @Test
    func `target-deps catches a case-insensitive typo even with a single external`() {
        // The single-external fallback would otherwise route `snapkit` to ExtPkg.
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg")],
            targetDependencies: ["ExtPkg", "snapkit"]
        )
        let error = #expect(throws: AppConfigError.self) { try config.validate() }
        if case let .misspelledProduct(_, suggestions) = error {
            #expect(suggestions == ["SnapKit"])
        } else {
            Issue.record("Expected .misspelledProduct, got \(String(describing: error))")
        }
    }

    @Test
    func `validate() accepts single external + multi-product target-deps (multi-product framework case)`() throws {
        // One external declaration, multiple products linked.
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg")],
            targetDependencies: ["ExtPkgCore", "ExtPkgUI"]
        )
        try config.validate()
    }

    @Test
    func `validate() rejects single external with empty target-deps`() {
        // A declared external without any target-deps is dangling.
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg")],
            targetDependencies: []
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `validate() accepts multi-external + multi-product target-deps (relaxed routing)`() throws {
        // Two declared externals + target-deps that reference products from each,
        // routed by longest name prefix.
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg"), external("MultiLib")],
            targetDependencies: ["ExtPkgCore", "ExtPkgUI", "MultiLibUI"]
        )
        try config.validate()
    }

    /// Regression: with two externals, linking only one passed.
    @Test
    func `validate() rejects multiple externals when one is never linked`() {
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg"), external("MultiLib")],
            targetDependencies: ["ExtPkg"]
        )
        let error = #expect(throws: AppConfigError.self) { try config.validate() }
        if case let .externalPackageNotConsumed(names) = error {
            #expect(names == ["MultiLib"])
        } else {
            Issue.record("Expected .externalPackageNotConsumed, got \(String(describing: error))")
        }
        // The message no longer claims the entry is dropped: it is emitted, unused.
        #expect(error?.description.contains("silently dropped") == false)
    }

    @Test
    func `validate() rejects multiple externals with empty target-deps`() {
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg"), external("MultiLib")],
            targetDependencies: []
        )
        #expect(throws: AppConfigError.self) { try config.validate() }
    }

    @Test
    func `an external overriding LumiKit is linked by the lumiKit feature`() throws {
        let override = ExternalPackage(name: "LumiKit", url: "../LumiKit", requirement: "", packageName: nil)
        try makeConfigWithExternals(externalPackages: [override], features: [.lumiKit]).validate()
    }

    @Test
    func `duplicate external names are rejected`() {
        let config = makeConfigWithExternals(
            externalPackages: [external("ExtPkg"), external("ExtPkg")],
            targetDependencies: ["ExtPkg"]
        )
        let error = #expect(throws: AppConfigError.self) { try config.validate() }
        if case let .duplicateExternalPackageNames(names) = error {
            #expect(names == ["ExtPkg"])
        } else {
            Issue.record("Expected .duplicateExternalPackageNames, got \(String(describing: error))")
        }
    }

    // MARK: - Persistence

    @Test
    func `swiftData and coreData together are rejected`() {
        let error = #expect(throws: AppConfigError.self) {
            try makeConfig(features: [.swiftData, .coreData]).validate()
        }
        #expect(error?.description.contains("choose one persistence layer") == true)
    }

    @Test
    func `cloudKitSharing requires coreData, not swiftData`() throws {
        let error = #expect(throws: AppConfigError.self) {
            try makeConfig(features: [.swiftData, .cloudKitSharing]).validate()
        }
        #expect(error?.description.contains("SwiftData has no shared-database support") == true)
        try makeConfig(features: [.coreData, .cloudKitSharing]).validate()
        try makeConfig(features: [.swiftData, .cloudKit]).validate()
    }

    // MARK: - validateForGeneration

    private func withField(
        name: String = "TestApp",
        bundleID: String = "com.test.app",
        deploymentTarget: String = "18.0",
        platforms: Set<Platform> = [.iPhone],
        projectSystem: ProjectSystem = .xcodeProj,
        tabs: [TabDefinition] = [],
        primaryColor: String = "#007AFF",
        locales: [String] = ["en"]
    ) -> AppConfig {
        AppConfig(
            name: name,
            bundleID: bundleID,
            deploymentTarget: deploymentTarget,
            platforms: platforms,
            projectSystem: projectSystem,
            tabs: tabs,
            primaryColor: primaryColor,
            features: [],
            author: "Test",
            licenseType: .proprietary,
            locales: locales
        )
    }

    @Test
    func `validateForGeneration accepts the defaults`() throws {
        try withField().validateForGeneration()
        try withField(tabs: [TabDefinition(name: "Home", icon: "house"), TabDefinition(name: "Settings", icon: "gear")], locales: ["en", "zh-Hans", "es"])
            .validateForGeneration()
    }

    /// Regression: `--load-config` skipped every check but the project system,
    /// so `"primaryColor": "red"` became black and `"name": ""` targeted the cwd.
    @Test
    func `validateForGeneration rejects every malformed field`() {
        let configs: [AppConfig] = [
            withField(name: "my-app"),
            withField(name: ""),
            withField(name: "../escaped"),
            withField(bundleID: "com.example.café"),
            withField(deploymentTarget: "17.0"),
            withField(platforms: []),
            withField(projectSystem: .spm),
            withField(primaryColor: "red"),
            withField(tabs: [TabDefinition(name: "my-tab", icon: "house")]),
            withField(tabs: [TabDefinition(name: "Default", icon: "house")]),
            withField(tabs: [TabDefinition(name: "Home", icon: "")]),
            withField(tabs: [TabDefinition(name: "Home", icon: "house"), TabDefinition(name: "home", icon: "gear")]),
            withField(locales: ["english"]),
            withField(locales: ["en", "en"]),
        ]
        for config in configs {
            #expect(throws: (any Error).self, "\(config.name) \(config.bundleID) \(config.primaryColor)") {
                try config.validateForGeneration()
            }
        }
    }

    @Test
    func `validateForGeneration names the spm project system`() {
        let error = #expect(throws: ConfigValidationError.self) {
            try withField(projectSystem: .spm).validateForGeneration()
        }
        #expect(error?.description.contains("projectSystem 'spm'") == true)
        #expect(error?.description.contains("not supported for apps") == true)
    }

    // MARK: - --features parsing

    @Test
    func `parseList reads app features`() throws {
        #expect(try AppFeature.parseList(" coreData , lumiKit ") == [.coreData, .lumiKit])
        #expect(try AppFeature.parseList(nil).isEmpty)
    }

    /// Regression: unknown tokens only warned, and derived features were dropped.
    @Test
    func `parseList rejects unknown and derived features`() {
        let unknown = #expect(throws: ConfigValidationError.self) { try AppFeature.parseList("swiftdata") }
        #expect(unknown?.description.contains("Did you mean 'swiftData'?") == true)

        let tabs = #expect(throws: ConfigValidationError.self) { try AppFeature.parseList("tabs") }
        #expect(tabs?.description.contains("--tabs") == true)
        let catalyst = #expect(throws: ConfigValidationError.self) { try AppFeature.parseList("macCatalyst") }
        #expect(catalyst?.description.contains("--platforms") == true)
        let hook = #expect(throws: ConfigValidationError.self) { try AppFeature.parseList("coreDataAuditHook") }
        #expect(hook?.description.contains("auto-derived from gitHooks + persistence") == true)
    }

    @Test
    func `parseList keeps the removed-alias migration error`() {
        let error = #expect(throws: ConfigValidationError.self) { try AppFeature.parseList("snapKit,lookin") }
        #expect(error?.description.contains("snapKit → --use-packages SnapKit") == true)
        #expect(error?.description.contains("lookin → --use-packages LookinServer") == true)
    }

    // MARK: - --external-packages parsing

    @Test
    func `local-path external package parses and validates`() throws {
        let parsed = try ExternalPackage.parse("ExtPkg=/Users/me/Projects/ExtPkg")
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "ExtPkg")
        #expect(parsed[0].url == "/Users/me/Projects/ExtPkg")
        #expect(parsed[0].requirement.isEmpty)
        #expect(parsed[0].isLocalPath == true)

        // Relative path also works.
        let relative = try ExternalPackage.parse("MultiLib=../MultiLib")
        #expect(relative[0].url == "../MultiLib")
        #expect(relative[0].isLocalPath == true)

        // Path form with explicit packageName.
        let withName = try ExternalPackage.parse("ExtPkgCore=/abs/ExtPkg:ExtPkg")
        #expect(withName[0].url == "/abs/ExtPkg")
        #expect(withName[0].packageName == "ExtPkg")
        #expect(withName[0].isLocalPath == true)
    }

    @Test
    func `URL-form external package still parses correctly after path-form addition`() throws {
        // Regression check: URL form must keep working unchanged.
        let parsed = try ExternalPackage.parse("ExtPkg=https://example.com/ExtPkg:from: \"0.3.0\"")
        #expect(parsed.count == 1)
        #expect(parsed[0].url == "https://example.com/ExtPkg")
        #expect(parsed[0].requirement == "from: \"0.3.0\"")
        #expect(parsed[0].isLocalPath == false)
    }

    /// Regression: the scp-style form the docs advertise was read as a path,
    /// `path: git@github.com:o/alpha.git:from: "1.0.0"`.
    @Test
    func `scp-style git URL parses as a URL with its requirement`() throws {
        let parsed = try ExternalPackage.parse(#"Alpha=git@github.com:o/alpha.git:from: "1.0.0""#)
        #expect(parsed.count == 1)
        #expect(parsed[0].url == "git@github.com:o/alpha.git")
        #expect(parsed[0].requirement == #"from: "1.0.0""#)
        #expect(parsed[0].isLocalPath == false)
        #expect(parsed[0].packageName == nil)

        let withName = try ExternalPackage.parse(#"AlphaCore=git@github.com:o/alpha.git:branch: "main":Alpha"#)
        #expect(withName[0].url == "git@github.com:o/alpha.git")
        #expect(withName[0].requirement == #"branch: "main""#)
        #expect(withName[0].packageName == "Alpha")

        #expect(throws: ExternalPackage.ParseError.self) { try ExternalPackage.parse("Alpha=git@github.com:o/alpha.git") }
    }

    @Test
    func `Codable round-trips externalPackages and targetDependencies`() throws {
        let original = makeConfigWithExternals(
            externalPackages: [external("ExtPkg")],
            targetDependencies: ["ExtPkg", "ExtPkgUI"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.externalPackages.count == 1)
        #expect(decoded.externalPackages.first?.name == "ExtPkg")
        #expect(decoded.targetDependencies == ["ExtPkg", "ExtPkgUI"])
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

    /// Regression: `--use-packages ':'` trapped on `parts[0]` of an empty split.
    @Test
    func `parseUsePackages rejects an empty identifier or version`() {
        for input in [":", ":1.0.0", "SnapKit:", " : "] {
            #expect(throws: ExternalPackage.UsePackagesParseError.self, "\(input)") {
                try ExternalPackage.parseUsePackages(input)
            }
        }
    }

    /// Regression: internal registry entries were accepted and emitted
    /// `product: LumiKit`, which doesn't exist.
    @Test
    func `parseUsePackages rejects internal registry entries with a pointer`() {
        let lumiKit = #expect(throws: ExternalPackage.UsePackagesParseError.self) { try ExternalPackage.parseUsePackages("LumiKit") }
        #expect(lumiKit?.description.contains("--features lumiKit") == true)
        let argumentParser = #expect(throws: ExternalPackage.UsePackagesParseError.self) { try ExternalPackage.parseUsePackages("ArgumentParser") }
        #expect(argumentParser?.description.contains("automatically") == true)
        let typo = #expect(throws: ExternalPackage.UsePackagesParseError.self) { try ExternalPackage.parseUsePackages("Snapkit") }
        #expect(typo?.description.contains("Did you mean 'SnapKit'?") == true)
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
    func `KnownPackages.removedFeatureAliases points snapKit + lookin at the registry`() {
        #expect(KnownPackages.removedFeatureAliases["snapKit"] == "SnapKit")
        #expect(KnownPackages.removedFeatureAliases["lookin"] == "LookinServer")
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

// MARK: - ProjectSystem app support

struct ProjectSystemAppSupportTests {
    @Test
    func `only xcodeproj and xcodegen can back an app`() {
        #expect(ProjectSystem.xcodeProj.isSupportedForApps)
        #expect(ProjectSystem.xcodeGen.isSupportedForApps)
        #expect(!ProjectSystem.spm.isSupportedForApps)
    }

    @Test
    func `isSupportedForApps agrees with appOptions for every case`() {
        for system in ProjectSystem.allCases {
            #expect(system.isSupportedForApps == ProjectSystem.appOptions.contains(system))
        }
    }

    @Test
    func `rejection reason names the signing constraint and both valid systems`() {
        let reason = ProjectSystem.unsupportedForAppsReason
        #expect(reason.contains("code signing"))
        #expect(reason.contains("entitlements"))
        #expect(reason.contains("xcodeproj"))
        #expect(reason.contains("xcodegen"))
        // Points at the commands that DO support SPM, so the error is actionable.
        #expect(reason.contains("monolith new package"))
        #expect(reason.contains("monolith new cli"))
        // Must not advertise spm as a valid choice for apps.
        #expect(!reason.contains("Valid for apps: spm"))
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
