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

    // MARK: - Backward-Compatible Decoding

    enum CodingKeys: String, CodingKey {
        case name, bundleID, deploymentTarget, platforms, projectSystem,
             tabs, primaryColor, features, author, licenseType
    }

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
        licenseType: LicenseType = .proprietary
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
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        deploymentTarget = try container.decode(String.self, forKey: .deploymentTarget)
        platforms = try container.decode(Set<Platform>.self, forKey: .platforms)
        projectSystem = try container.decode(ProjectSystem.self, forKey: .projectSystem)
        tabs = try container.decode([TabDefinition].self, forKey: .tabs)
        primaryColor = try container.decode(String.self, forKey: .primaryColor)
        features = try container.decode(Set<AppFeature>.self, forKey: .features)
        author = try container.decode(String.self, forKey: .author)
        licenseType = try container.decodeIfPresent(LicenseType.self, forKey: .licenseType) ?? .proprietary
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
}
