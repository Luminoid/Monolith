enum Preset: String, CaseIterable {
    case minimal
    case standard
    case full

    var displayName: String {
        switch self {
        case .minimal: "Minimal (no features)"
        case .standard: "Standard (devTooling, gitHooks, claudeMD, privacyManifest)"
        case .full: "Full (every non-legacy feature, with Core Data for persistence)"
        }
    }

    /// The app features a preset selects. `full` is every prompted feature
    /// except the legacy ones (`rSwift`, `fastlane`; still available through
    /// `--features`) and `swiftData`: an app has one persistence layer, and
    /// Core Data is the one that supports CloudKit sharing, which `full`
    /// also selects.
    func appFeatures() -> Set<AppFeature> {
        switch self {
        case .minimal:
            []
        case .standard:
            [.devTooling, .gitHooks, .claudeMD, .privacyManifest]
        case .full:
            Set(AppFeature.promptOptions).subtracting([.rSwift, .fastlane, .swiftData])
        }
    }

    func packageFeatures() -> Set<PackageFeature> {
        switch self {
        case .minimal:
            []
        case .standard:
            [.devTooling, .gitHooks, .claudeMD]
        case .full:
            // .strictConcurrency is a no-op at swift-tools-version 6.2 and emits
            // a warning when set explicitly; the `full` preset omits it so a
            // clean `--preset full` run produces no spurious stderr.
            Set(PackageFeature.allCases).subtracting([.strictConcurrency])
        }
    }

    func cliFeatures() -> Set<CLIFeature> {
        switch self {
        case .minimal:
            []
        case .standard:
            [.devTooling, .gitHooks, .claudeMD]
        case .full:
            // Same rationale as packageFeatures: drop the no-op flag.
            Set(CLIFeature.allCases).subtracting([.strictConcurrency])
        }
    }
}
