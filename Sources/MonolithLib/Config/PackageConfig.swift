struct PackageConfig: Codable {
    let name: String
    let platforms: [PlatformVersion]
    let targets: [TargetDefinition]
    let features: Set<PackageFeature>
    let mainActorTargets: Set<String>
    let author: String
    let licenseType: LicenseType

    // MARK: - Backward-Compatible Decoding

    enum CodingKeys: String, CodingKey {
        case name, platforms, targets, features, mainActorTargets, author, licenseType
    }

    init(
        name: String,
        platforms: [PlatformVersion],
        targets: [TargetDefinition],
        features: Set<PackageFeature>,
        mainActorTargets: Set<String>,
        author: String,
        licenseType: LicenseType = .mit
    ) {
        self.name = name
        self.platforms = platforms
        self.targets = targets
        self.features = features
        self.mainActorTargets = mainActorTargets
        self.author = author
        self.licenseType = licenseType
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        platforms = try container.decode([PlatformVersion].self, forKey: .platforms)
        targets = try container.decode([TargetDefinition].self, forKey: .targets)
        features = try container.decode(Set<PackageFeature>.self, forKey: .features)
        mainActorTargets = try container.decode(Set<String>.self, forKey: .mainActorTargets)
        author = try container.decode(String.self, forKey: .author)
        licenseType = try container.decodeIfPresent(LicenseType.self, forKey: .licenseType) ?? .mit
    }

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
