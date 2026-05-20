struct AppConfig: Codable {
    let name: String
    let bundleID: String
    let deploymentTarget: String
    let platforms: Set<Platform>
    let projectSystem: ProjectSystem
    let tabs: [TabDefinition]
    let primaryColor: String
    let features: Set<AppFeature>
    let author: String
    let licenseType: LicenseType

    /// Resolved features including auto-derived ones.
    var resolvedFeatures: Set<AppFeature> {
        var resolved = features

        // Tabs feature is derived from non-empty tabs array
        if !tabs.isEmpty {
            resolved.insert(.tabs)
        }

        // Mac Catalyst feature is auto-enabled when platform is selected
        if platforms.contains(.macCatalyst) {
            resolved.insert(.macCatalyst)
        }

        // Dark mode is auto-enabled when LumiKit is selected
        // (LumiKit includes full theme support which supersedes standalone dark mode)
        if resolved.contains(.lumiKit) {
            resolved.insert(.darkMode)
        }

        // CloudKit sharing implies CloudKit
        if resolved.contains(.cloudKitSharing) {
            resolved.insert(.cloudKit)
        }

        // CloudKit requires either Core Data or SwiftData. If neither is selected,
        // default to Core Data (the more stable CloudKit-backed persistence layer).
        if resolved.contains(.cloudKit), !resolved.contains(.swiftData), !resolved.contains(.coreData) {
            resolved.insert(.coreData)
        }

        // Auto-derive the Core Data audit hook when both persistence + CloudKit are active.
        if resolved.contains(.cloudKit), resolved.contains(.gitHooks),
           resolved.contains(.coreData) || resolved.contains(.swiftData) {
            resolved.insert(.coreDataAuditHook)
        }

        return resolved
    }

    /// Whether the app uses SwiftData.
    var hasSwiftData: Bool {
        resolvedFeatures.contains(.swiftData)
    }

    /// Whether the app uses LumiKit.
    var hasLumiKit: Bool {
        resolvedFeatures.contains(.lumiKit)
    }

    /// Whether the app uses SnapKit.
    var hasSnapKit: Bool {
        resolvedFeatures.contains(.snapKit)
    }

    /// Whether the app uses Lottie.
    var hasLottie: Bool {
        resolvedFeatures.contains(.lottie)
    }

    /// Whether the app uses LookinServer (UI debugging, iOS only).
    var hasLookin: Bool {
        resolvedFeatures.contains(.lookin)
    }

    /// Whether the app supports dark mode (standalone or via LumiKit).
    var hasDarkMode: Bool {
        resolvedFeatures.contains(.darkMode)
    }

    /// Whether the app includes Combine/async patterns.
    var hasCombine: Bool {
        resolvedFeatures.contains(.combine)
    }

    /// Whether the app uses dev tooling.
    var hasDevTooling: Bool {
        resolvedFeatures.contains(.devTooling)
    }

    /// Whether the app uses git hooks.
    var hasGitHooks: Bool {
        resolvedFeatures.contains(.gitHooks)
    }

    /// Whether the app includes localization support.
    var hasLocalization: Bool {
        resolvedFeatures.contains(.localization)
    }

    /// Whether the app has tabs.
    var hasTabs: Bool {
        !tabs.isEmpty
    }

    /// Whether the app targets Mac Catalyst.
    var hasMacCatalyst: Bool {
        platforms.contains(.macCatalyst)
    }

    /// Whether the app uses Core Data for persistence.
    var hasCoreData: Bool {
        resolvedFeatures.contains(.coreData)
    }

    /// Whether the app syncs persistence through CloudKit.
    var hasCloudKit: Bool {
        resolvedFeatures.contains(.cloudKit)
    }

    /// Whether the app accepts CloudKit shares (Family Sharing-style).
    var hasCloudKitSharing: Bool {
        resolvedFeatures.contains(.cloudKitSharing)
    }

    /// Whether the app registers for CloudKit silent push notifications.
    /// Auto-enabled with CloudKit; the AppDelegate calls
    /// `registerForRemoteNotifications()` and the Info.plist declares
    /// `UIBackgroundModes: remote-notification`.
    var hasCloudKitNotifications: Bool {
        hasCloudKit
    }

    /// Whether the app uses UNUserNotificationCenter (foreground notifications).
    var hasNotifications: Bool {
        resolvedFeatures.contains(.notifications)
    }

    /// Whether the app handles deep links via URL scheme.
    var hasDeepLinks: Bool {
        resolvedFeatures.contains(.deepLinks)
    }

    /// Whether the app handles Spotlight CSSearchable item activations.
    var hasSpotlight: Bool {
        resolvedFeatures.contains(.spotlight)
    }

    /// Whether the SceneDelegate emits a `deferLaunchWork()` helper.
    var hasDeferredLaunchWork: Bool {
        resolvedFeatures.contains(.deferredLaunchWork)
    }

    /// Whether the app generates a WidgetKit extension target.
    var hasWidget: Bool {
        resolvedFeatures.contains(.widget)
    }

    /// Whether to emit `PrivacyInfo.xcprivacy` files (app + every extension).
    /// Strongly recommended for App Store submissions.
    var hasPrivacyManifest: Bool {
        resolvedFeatures.contains(.privacyManifest)
    }

    /// Whether to emit the app icon alpha-channel validator script.
    var hasAppIconValidation: Bool {
        resolvedFeatures.contains(.appIconValidation)
    }

    /// Whether the pre-commit hook includes the Core Data audit reminder.
    var hasCoreDataAuditHook: Bool {
        resolvedFeatures.contains(.coreDataAuditHook)
    }

    /// App Group identifier for sharing data with extensions (widget, share).
    /// Derived from the bundle ID with a `group.` prefix.
    var appGroupIdentifier: String {
        "group.\(bundleID)"
    }

    /// Warnings about deprecated or legacy features. Caller is responsible for
    /// printing these (typically to stderr in CLI commands).
    var deprecationWarnings: [String] {
        var warnings: [String] = []
        if features.contains(.rSwift) {
            warnings.append(
                "warning: rSwift is supported for legacy projects only. Xcode 15+ has native type-safe resource accessors that supersede it. Consider omitting --features rSwift."
            )
        }
        if features.contains(.fastlane) {
            warnings.append(
                "warning: fastlane is supported for legacy projects only. Prefer the generated Makefile targets or Xcode Cloud for new projects. Consider omitting --features fastlane."
            )
        }
        return warnings
    }
}
