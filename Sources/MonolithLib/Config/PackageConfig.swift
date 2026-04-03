struct PackageConfig: Codable {
    let name: String
    let platforms: [PlatformVersion]
    let targets: [TargetDefinition]
    let features: Set<PackageFeature>
    let mainActorTargets: Set<String>
    let author: String
    let licenseType: LicenseType

    /// Whether strict concurrency is enabled.
    var hasStrictConcurrency: Bool {
        features.contains(.strictConcurrency)
    }

    /// Whether any target uses defaultIsolation: MainActor.
    var hasDefaultIsolation: Bool {
        features.contains(.defaultIsolation) && !mainActorTargets.isEmpty
    }

    /// Whether dev tooling is enabled.
    var hasDevTooling: Bool {
        features.contains(.devTooling)
    }

    /// Whether git hooks are enabled.
    var hasGitHooks: Bool {
        features.contains(.gitHooks)
    }
}
