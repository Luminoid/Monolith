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
            author: "Test"
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
        let config = makeConfig(features: [.swiftData, .snapKit, .lottie, .lookin, .combine, .devTooling, .gitHooks, .localization])
        #expect(config.hasSwiftData)
        #expect(config.hasSnapKit)
        #expect(config.hasLottie)
        #expect(config.hasLookin)
        #expect(config.hasCombine)
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
        #expect(config.hasLocalization)
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
