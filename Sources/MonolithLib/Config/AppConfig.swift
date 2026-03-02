struct AppConfig: Sendable {
    let name: String
    let bundleID: String
    let deploymentTarget: String
    let platforms: Set<Platform>
    let projectSystem: ProjectSystem
    let tabs: [TabDefinition]
    let primaryColor: String
    let features: Set<AppFeature>
    let author: String

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
    var hasSwiftData: Bool { resolvedFeatures.contains(.swiftData) }

    /// Whether the app uses LumiKit.
    var hasLumiKit: Bool { resolvedFeatures.contains(.lumiKit) }

    /// Whether the app uses SnapKit.
    var hasSnapKit: Bool { resolvedFeatures.contains(.snapKit) }

    /// Whether the app uses Lottie.
    var hasLottie: Bool { resolvedFeatures.contains(.lottie) }

    /// Whether the app supports dark mode (standalone or via LumiKit).
    var hasDarkMode: Bool { resolvedFeatures.contains(.darkMode) }

    /// Whether the app includes Combine/async patterns.
    var hasCombine: Bool { resolvedFeatures.contains(.combine) }

    /// Whether the app uses dev tooling.
    var hasDevTooling: Bool { resolvedFeatures.contains(.devTooling) }

    /// Whether the app has tabs.
    var hasTabs: Bool { !tabs.isEmpty }

    /// Whether the app targets Mac Catalyst.
    var hasMacCatalyst: Bool { platforms.contains(.macCatalyst) }
}
