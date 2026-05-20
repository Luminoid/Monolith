enum Preset: String, CaseIterable {
    case minimal
    case standard
    case full

    var displayName: String {
        switch self {
        case .minimal: "Minimal (no features)"
        case .standard: "Standard (devTooling, gitHooks, claudeMD, privacyManifest)"
        case .full: "Full (every non-legacy feature)"
        }
    }

    func appFeatures(projectSystem: ProjectSystem) -> Set<AppFeature> {
        switch self {
        case .minimal:
            return []
        case .standard:
            return [.devTooling, .gitHooks, .claudeMD, .privacyManifest]
        case .full:
            var features = Set(AppFeature.promptOptions)
            // Skip legacy features in the "full" preset — users can still opt in
            // explicitly via --features rSwift,fastlane.
            features.remove(.rSwift)
            features.remove(.fastlane)
            // R.swift and fastlane need .xcodeproj/.xcodeGen, not SPM.
            if projectSystem == .spm {
                features.remove(.rSwift)
                features.remove(.fastlane)
            }
            return features
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
