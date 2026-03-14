import Foundation
import Testing
@testable import MonolithLib

@Suite("AppConfig")
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
            projectSystem: .spm,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test"
        )
    }

    // MARK: - resolvedFeatures

    @Test("empty features resolve to empty")
    func emptyFeatures() {
        let config = makeConfig()
        #expect(config.resolvedFeatures.isEmpty)
    }

    @Test("tabs auto-derived from non-empty tabs array")
    func tabsAutoDerived() {
        let config = makeConfig(tabs: [TabDefinition(name: "Home", icon: "house")])
        #expect(config.resolvedFeatures.contains(.tabs))
    }

    @Test("tabs not derived when tabs array is empty")
    func tabsNotDerivedWhenEmpty() {
        let config = makeConfig(features: [.swiftData])
        #expect(!config.resolvedFeatures.contains(.tabs))
    }

    @Test("macCatalyst auto-derived from platform")
    func macCatalystAutoDerived() {
        let config = makeConfig(platforms: [.iPhone, .macCatalyst])
        #expect(config.resolvedFeatures.contains(.macCatalyst))
    }

    @Test("macCatalyst not derived when platform not selected")
    func macCatalystNotDerivedWithoutPlatform() {
        let config = makeConfig(platforms: [.iPhone, .iPad])
        #expect(!config.resolvedFeatures.contains(.macCatalyst))
    }

    @Test("darkMode auto-derived from lumiKit")
    func darkModeAutoDerivedFromLumiKit() {
        let config = makeConfig(features: [.lumiKit])
        #expect(config.resolvedFeatures.contains(.darkMode))
    }

    @Test("darkMode not derived without lumiKit")
    func darkModeNotDerivedWithoutLumiKit() {
        let config = makeConfig(features: [.swiftData])
        #expect(!config.resolvedFeatures.contains(.darkMode))
    }

    @Test("explicit features preserved in resolved set")
    func explicitFeaturesPreserved() {
        let config = makeConfig(features: [.swiftData, .combine, .devTooling])
        let resolved = config.resolvedFeatures
        #expect(resolved.contains(.swiftData))
        #expect(resolved.contains(.combine))
        #expect(resolved.contains(.devTooling))
    }

    @Test("all auto-derivations combine correctly")
    func allAutoDerived() {
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

    @Test("hasTabs checks tabs array, not feature set")
    func hasTabsChecksArray() {
        let config = makeConfig(features: [.tabs])
        #expect(!config.hasTabs, "hasTabs should be false when tabs array is empty")
    }

    @Test("hasMacCatalyst checks platforms, not feature set")
    func hasMacCatalystChecksPlatforms() {
        let config = makeConfig(features: [.macCatalyst])
        #expect(!config.hasMacCatalyst, "hasMacCatalyst should be false when platform not included")
    }

    @Test("convenience properties match resolved features")
    func convenienceProperties() {
        let config = makeConfig(features: [.swiftData, .snapKit, .lottie, .combine, .devTooling, .gitHooks, .localization])
        #expect(config.hasSwiftData)
        #expect(config.hasSnapKit)
        #expect(config.hasLottie)
        #expect(config.hasCombine)
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
        #expect(config.hasLocalization)
    }
}

// MARK: - Platform displayName

@Suite("Platform displayName")
struct PlatformDisplayNameTests {
    @Test("all platforms have display names")
    func allDisplayNames() {
        #expect(Platform.iPhone.displayName == "iPhone")
        #expect(Platform.iPad.displayName == "iPad")
        #expect(Platform.macCatalyst.displayName == "Mac Catalyst")
    }

    @Test("all cases have non-empty display names")
    func allCasesHaveDisplayNames() {
        for platform in Platform.allCases {
            #expect(!platform.displayName.isEmpty)
        }
    }
}

// MARK: - ProjectSystem displayName

@Suite("ProjectSystem displayName")
struct ProjectSystemDisplayNameTests {
    @Test("all project systems have display names")
    func allDisplayNames() {
        #expect(ProjectSystem.spm.displayName == "SPM (Swift Package Manager)")
        #expect(ProjectSystem.xcodeGen.displayName == "XcodeGen")
    }
}

// MARK: - PackagePlatform

@Suite("PackagePlatform")
struct PackagePlatformTests {
    @Test("all platforms have display names")
    func allDisplayNames() {
        #expect(PackagePlatform.iOS.displayName == "iOS")
        #expect(PackagePlatform.macOS.displayName == "macOS")
        #expect(PackagePlatform.macCatalyst.displayName == "Mac Catalyst")
        #expect(PackagePlatform.watchOS.displayName == "watchOS")
        #expect(PackagePlatform.tvOS.displayName == "tvOS")
        #expect(PackagePlatform.visionOS.displayName == "visionOS")
    }

    @Test("all platforms have default versions")
    func allDefaultVersions() {
        for platform in PackagePlatform.allCases {
            #expect(Validators.validatePlatformVersion(platform.defaultVersion),
                    "\(platform.displayName) default version '\(platform.defaultVersion)' should be valid")
        }
    }

    @Test("platformName matches rawValue")
    func platformNameMatchesRawValue() {
        for platform in PackagePlatform.allCases {
            #expect(platform.platformName == platform.rawValue)
        }
    }
}
