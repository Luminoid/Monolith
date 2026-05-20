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
            Set(PackageFeature.allCases)
        }
    }

    func cliFeatures() -> Set<CLIFeature> {
        switch self {
        case .minimal:
            []
        case .standard:
            [.devTooling, .gitHooks, .claudeMD]
        case .full:
            Set(CLIFeature.allCases)
        }
    }
}
