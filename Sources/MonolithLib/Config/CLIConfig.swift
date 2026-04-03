struct CLIConfig: Codable {
    let name: String
    let includeArgumentParser: Bool
    let features: Set<CLIFeature>
    let author: String
    let licenseType: LicenseType

    /// Whether dev tooling is enabled.
    var hasDevTooling: Bool {
        features.contains(.devTooling)
    }

    /// Whether git hooks are enabled.
    var hasGitHooks: Bool {
        features.contains(.gitHooks)
    }

    /// Whether strict concurrency is enabled.
    var hasStrictConcurrency: Bool {
        features.contains(.strictConcurrency)
    }
}
