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
    /// Third-party SPM packages declared via `--external-packages` (matches the
    /// `monolith new package` surface). Empty by default; entries are wired into
    /// the generated `project.yml` (`packages:` block) or `Package.swift`
    /// (`dependencies:` list) depending on `projectSystem`.
    let externalPackages: [ExternalPackage]
    /// Product names to link into the app's main target via `--target-deps`.
    /// May reference an entry in `externalPackages` (by `name`), a built-in
    /// (SnapKit, LumiKitUI, etc. — those are auto-wired from features, but
    /// listing them here is harmless and explicit), or another already-known
    /// SPM product. The app generator emits one `- package:` / `.product(...)`
    /// entry per dep, looking up the package name from the external-package
    /// registry plus the built-in feature wiring.
    let targetDependencies: [String]

    /// Memberwise init with defaults for the new external-package fields so
    /// existing call sites (and ~60 test fixtures) stay compiling.
    init(
        name: String,
        bundleID: String,
        deploymentTarget: String,
        platforms: Set<Platform>,
        projectSystem: ProjectSystem,
        tabs: [TabDefinition],
        primaryColor: String,
        features: Set<AppFeature>,
        author: String,
        licenseType: LicenseType,
        externalPackages: [ExternalPackage] = [],
        targetDependencies: [String] = []
    ) {
        self.name = name
        self.bundleID = bundleID
        self.deploymentTarget = deploymentTarget
        self.platforms = platforms
        self.projectSystem = projectSystem
        self.tabs = tabs
        self.primaryColor = primaryColor
        self.features = features
        self.author = author
        self.licenseType = licenseType
        self.externalPackages = externalPackages
        self.targetDependencies = targetDependencies
    }

    /// Custom Codable so older saved configs (without the new external-package
    /// fields) decode cleanly with empty defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.bundleID = try container.decode(String.self, forKey: .bundleID)
        self.deploymentTarget = try container.decode(String.self, forKey: .deploymentTarget)
        self.platforms = try container.decode(Set<Platform>.self, forKey: .platforms)
        self.projectSystem = try container.decode(ProjectSystem.self, forKey: .projectSystem)
        self.tabs = try container.decode([TabDefinition].self, forKey: .tabs)
        self.primaryColor = try container.decode(String.self, forKey: .primaryColor)
        self.features = try container.decode(Set<AppFeature>.self, forKey: .features)
        self.author = try container.decode(String.self, forKey: .author)
        self.licenseType = try container.decode(LicenseType.self, forKey: .licenseType)
        self.externalPackages = try container.decodeIfPresent([ExternalPackage].self, forKey: .externalPackages) ?? []
        self.targetDependencies = try container.decodeIfPresent([String].self, forKey: .targetDependencies) ?? []
    }

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

    /// Whether the app pulls in SnapKit. Now sourced from
    /// `--use-packages SnapKit` or `--external-packages` rather than a
    /// feature flag — checks the synthesized external-packages list.
    var hasSnapKit: Bool {
        externalPackages.contains(where: { $0.spmPackageName == "SnapKit" })
    }

    /// Whether the app uses Lottie. Still a feature because Monolith emits
    /// a `LottieHelper.swift` starter template (not just a dep wire).
    var hasLottie: Bool {
        resolvedFeatures.contains(.lottie)
    }

    /// Whether the app pulls in LookinServer (iOS-only debug overlay).
    /// Sourced from `--use-packages LookinServer` or `--external-packages`.
    var hasLookin: Bool {
        externalPackages.contains(where: { $0.spmPackageName == "LookinServer" })
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

    /// Validates `externalPackages` + `targetDependencies`. Called from
    /// `NewAppCommand` after parsing the CLI flags. No-op when both lists are
    /// empty (the existing happy path).
    ///
    /// Rules:
    /// 1. External package names must not collide with the app target name.
    /// 2. When any externals are declared, target-deps must be non-empty.
    ///    The generator does best-effort product → package routing (direct
    ///    name match → fall back to single declared external → fall back to
    ///    product=package). Multi-product multi-package cases that need
    ///    explicit disambiguation use the optional `:packageName` segment.
    func validate() throws(AppConfigError) {
        if externalPackages.isEmpty, targetDependencies.isEmpty {
            return
        }

        // 1. Name collision with the app target.
        for ext in externalPackages where ext.name == name {
            throw .externalPackageCollidesWithTarget(ext.name)
        }

        // 2. Externals declared → target-deps must be non-empty.
        // (An external with empty target-deps is dangling — the generator
        // would emit a `packages:` entry that no target consumes, which xcodebuild
        // resolves but flags as an unused package warning.)
        if !externalPackages.isEmpty, targetDependencies.isEmpty {
            throw .externalPackageNotConsumed(externalPackages.map(\.name).sorted())
        }
    }
}

enum AppConfigError: Error, CustomStringConvertible {
    case externalPackageCollidesWithTarget(String)
    case externalPackageNotConsumed([String])

    var description: String {
        switch self {
        case let .externalPackageCollidesWithTarget(name):
            return "--external-packages declares '\(name)', which collides with the app target name. External package names must not match the app target."
        case let .externalPackageNotConsumed(names):
            let quoted = names.map { "'\($0)'" }.joined(separator: ", ")
            let pronoun = names.count == 1 ? "it" : "them"
            return "--external-packages declares \(quoted), but --target-deps does not reference \(pronoun). "
                + "Unreferenced entries are silently dropped from the generated project file. "
                + "Add the name to --target-deps, or remove the --external-packages entry."
        }
    }
}
