import Foundation
import Testing
@testable import MonolithLib

struct ProjectStateTests {
    private func withScaffold(
        features: Set<AppFeature>,
        platforms: Set<Platform> = [.iPhone],
        bundleID: String = "com.acme.myapp",
        body: (String) throws -> Void
    ) throws {
        let raw = NSTemporaryDirectory() + "monolith-state-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: raw) }
        try AppProjectGenerator.generate(config: AppConfig(
            name: "MyApp",
            bundleID: bundleID,
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        ), outputDir: raw)
        try body("\(raw)/MyApp")
    }

    private func scan(_ root: String) throws -> ProjectState {
        try ProjectState.scan(at: root, detected: ProjectDetector.detect(at: root))
    }

    // MARK: - Apps

    @Test
    func `an XcodeGen app's facts come from its own files`() throws {
        try withScaffold(features: [.coreData, .cloudKit, .localization, .appIconValidation, .widget], platforms: [.iPhone, .macCatalyst]) { root in
            let state = try scan(root)
            #expect(state.bundleID == "com.acme.myapp")
            #expect(state.deploymentTarget == "18.0")
            #expect(state.hasCoreDataModel)
            #expect(state.hasCloudKit)
            #expect(state.hasWidget)
            #expect(state.hasMacCatalyst)
            #expect(state.stringCatalogs == ["MyApp/Resources/Localizable.xcstrings"])
            #expect(state.hasLocalizationAudit)
            #expect(state.hasAppIconValidation)
            #expect(state.appIconSetPath == "MyApp/Resources/Assets.xcassets/AppIcon.appiconset")
            #expect(state.appEntitlementsPath == "MyApp/MyApp.entitlements")
            #expect(state.needsCoreDataAuditHook)
            #expect(state.disableTestParallelism)
            #expect(!state.hasSwiftDataModels)
            #expect(!state.linksLumiKit)
        }
    }

    /// Mirrors `new`: a Core Data app's suites share the stack singleton, so
    /// they run serially with or without CloudKit; SwiftData only with it.
    @Test
    func `Core Data apps run tests serially, SwiftData apps only with CloudKit`() {
        let facts: [(coreData: Bool, swiftData: Bool, cloudKit: Bool, serial: Bool)] = [
            (true, false, false, true), (true, false, true, true),
            (false, true, false, false), (false, true, true, true), (false, false, true, false),
        ]
        for fact in facts {
            var state = ProjectState(root: "/tmp", type: .app, name: "MyApp", projectSystem: .xcodeGen)
            state.hasCoreDataModel = fact.coreData
            state.hasSwiftDataModels = fact.swiftData
            state.hasCloudKit = fact.cloudKit
            #expect(state.disableTestParallelism == fact.serial, "\(fact)")
        }
    }

    /// The facts `add claudeMD` reads: a package's logging core, a CLI's library.
    @Test
    func `a package's logging core and a CLI's library are found`() throws {
        let raw = NSTemporaryDirectory() + "monolith-state-docs-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: raw) }
        let package = PackageConfig(
            name: "MultiLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MultiLibCore", dependencies: []), TargetDefinition(name: "MultiLibUI", dependencies: ["MultiLibCore"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        try PackageProjectGenerator.generate(config: package, outputDir: raw)
        try CLIProjectGenerator.generate(config: CLIConfig(name: "my-tool", features: [.argumentParser], author: "Test", licenseType: .apache2), outputDir: raw)

        let packageState = try scan("\(raw)/MultiLib")
        #expect(packageState.logCore == LogCoreGenerator.placement(for: package.mergingRequiredPlatforms()))
        #expect(packageState.logCore?.module == "MultiLibCore")
        let cliState = try scan("\(raw)/my-tool")
        #expect(cliState.type == .cli)
        #expect(cliState.hasCLIKitLibrary)
        #expect(cliState.logCore == nil)
    }

    @Test
    func `a plain app has none of the optional facts`() throws {
        try withScaffold(features: []) { root in
            let state = try scan(root)
            #expect(!state.hasCloudKit)
            #expect(!state.hasCoreDataModel)
            #expect(!state.hasMacCatalyst)
            #expect(!state.hasWidget)
            #expect(state.stringCatalogs.isEmpty)
            #expect(!state.definesMacWindowConstants)
            #expect(!state.needsCoreDataAuditHook)
            #expect(state.platforms == [.iPhone])
        }
    }

    @Test
    func `SwiftData models and LumiKit are detected`() throws {
        try withScaffold(features: [.swiftData, .lumiKit], platforms: [.iPhone, .iPad, .macCatalyst]) { root in
            let state = try scan(root)
            #expect(state.hasSwiftDataModels)
            #expect(state.linksLumiKit)
            #expect(state.definesMacWindowConstants)
            #expect(state.platforms == [.iPhone, .iPad])
        }
    }

    @Test
    func `the appConfig reflects the detected features`() throws {
        try withScaffold(features: [.lumiKit, .cloudKit]) { root in
            let config = try scan(root).appConfig()
            #expect(config.hasLumiKit)
            #expect(config.hasCloudKit)
            #expect(config.hasCoreData)
            #expect(config.bundleID == "com.acme.myapp")
            #expect(config.projectSystem == .xcodeGen)
        }
    }

    @Test
    func `an entitlements path under SRCROOT is read relative to the project`() {
        #expect(ProjectState.projectRelative("$(SRCROOT)/MyApp/MyApp.entitlements") == "MyApp/MyApp.entitlements")
        #expect(ProjectState.projectRelative("MyApp/MyApp.entitlements") == "MyApp/MyApp.entitlements")
    }

    // MARK: - project.pbxproj

    @Test
    func `the app target's settings are read through its configuration list`() {
        let pbxproj = """
        // !$*UTF8*$!
        {
        \tobjects = {
        \t\tAAA000000000000000000001 /* MyAppTests */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = AAA000000000000000000010 /* list */;
        \t\t\tname = MyAppTests;
        \t\t\tproductType = "com.apple.product-type.bundle.unit-test";
        \t\t};
        \t\tAAA000000000000000000002 /* MyApp */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = AAA000000000000000000020 /* list */;
        \t\t\tname = MyApp;
        \t\t\tproductType = "com.apple.product-type.application";
        \t\t};
        \t\tAAA000000000000000000011 /* Debug */ = {isa = XCBuildConfiguration; name = Debug; };
        \t\tAAA000000000000000000012 /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.acme.MyAppTests;
        \t\t\t};
        \t\t};
        \t\tAAA000000000000000000021 /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tCODE_SIGN_ENTITLEMENTS = MyApp/MyApp.entitlements;
        \t\t\t\t"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]" = "MyApp/Mac.entitlements";
        \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.acme.myapp";
        \t\t\t\tSUPPORTS_MACCATALYST = YES;
        \t\t\t};
        \t\t};
        \t\tAAA000000000000000000010 /* list */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\tAAA000000000000000000012 /* Debug */,
        \t\t\t);
        \t\t};
        \t\tAAA000000000000000000020 /* list */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\tAAA000000000000000000021 /* Debug */,
        \t\t\t);
        \t\t};
        \t};
        }
        """
        let settings = PBXProjectReader(text: pbxproj).appBuildSettings(targetName: "MyApp")
        #expect(settings["PRODUCT_BUNDLE_IDENTIFIER"] == "com.acme.myapp")
        #expect(settings["CODE_SIGN_ENTITLEMENTS"] == "MyApp/MyApp.entitlements")
        #expect(settings["CODE_SIGN_ENTITLEMENTS[sdk=macosx*]"] == "MyApp/Mac.entitlements")
        #expect(settings["SUPPORTS_MACCATALYST"] == "YES")
        #expect(PBXProjectReader(text: pbxproj).appBuildSettings(targetName: "Other").isEmpty)
    }

    // MARK: - Packages

    private let multiLibManifest = """
    // swift-tools-version: 6.2

    import PackageDescription

    let package = Package(
        name: "MultiLib",
        platforms: [
            .iOS(.v18),
            .macOS(.v15_4),
        ],
        products: [
            .library(name: "MultiLibCore", targets: ["MultiLibCore"]),
            .library(name: "MultiLibUI", targets: ["MultiLibUI"]),
            .executable(name: "multilib-tool", targets: ["multilib-tool"]),
        ],
        dependencies: [
            .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
        ],
        targets: [
            .target(
                name: "MultiLibCore",
                dependencies: [],
                path: "Sources/MultiLibCore" // a comment, with a comma
            ),
            .target(
                name: "MultiLibUI",
                dependencies: [
                    "MultiLibCore",
                ],
                swiftSettings: [
                    .defaultIsolation(MainActor.self),
                ]
            ),
            .executableTarget(
                name: "multilib-tool",
                dependencies: [
                    .product(name: "ArgumentParser", package: "swift-argument-parser"),
                ]
            ),
            .testTarget(name: "MultiLibCoreTests", dependencies: ["MultiLibCore"]),
        ]
    )
    """

    @Test
    func `a package manifest's targets, isolation, and platforms are read`() {
        let manifest = PackageManifestReader(manifest: multiLibManifest)
        #expect(manifest.targets.map(\.name) == ["MultiLibCore", "MultiLibUI", "multilib-tool"])
        #expect(manifest.targets.map(\.isExecutable) == [false, false, true])
        #expect(manifest.targets[1].dependencies == ["MultiLibCore"])
        #expect(manifest.targets[2].dependencies == ["ArgumentParser"])
        #expect(manifest.mainActorTargets == ["MultiLibUI"])
        #expect(manifest.platforms.map(\.platform) == ["iOS", "macOS"])
        #expect(manifest.platforms.map(\.version) == ["18.0", "15.4"])
    }

    @Test
    func `a package with MainActor targets builds through the umbrella scheme`() throws {
        let dir = NSTemporaryDirectory() + "monolith-state-pkg-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try multiLibManifest.write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)

        let state = try scan(dir)
        #expect(state.type == .package)
        #expect(state.packageRequiresXcodebuild)
        #expect(state.xcodeBuildScheme == "MultiLib-Package")
    }

    @Test
    func `a package depending on a UIKit-only product needs xcodebuild`() {
        let manifest = """
        let package = Package(
            name: "ExtPkg",
            targets: [
                .target(name: "ExtPkg", dependencies: [.product(name: "LumiKitUI", package: "LumiKit")]),
            ]
        )
        """
        var state = ProjectState(root: "/tmp", type: .package, name: "ExtPkg", projectSystem: nil)
        state.packageTargets = PackageManifestReader(manifest: manifest).targets
        #expect(state.packageRequiresXcodebuild)
        #expect(state.xcodeBuildScheme == "ExtPkg", "an eponymous single library keeps the named scheme")
    }
}
