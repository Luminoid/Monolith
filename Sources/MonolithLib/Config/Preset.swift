enum Preset: String, CaseIterable {
    case minimal
    case standard
    case full

    var displayName: String {
        switch self {
        case .minimal: "Minimal (no features)"
        case .standard: "Standard (devTooling, gitHooks, claudeMD)"
        case .full: "Full (all features)"
        }
    }

    func appFeatures(projectSystem: ProjectSystem) -> Set<AppFeature> {
        switch self {
        case .minimal:
            return []
        case .standard:
            return [.devTooling, .gitHooks, .claudeMD]
        case .full:
            var features = Set(AppFeature.promptOptions)
            // R.swift and fastlane need .xcodeproj — not available for SPM
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
