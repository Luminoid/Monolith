struct CLIConfig: Sendable, Codable {
    let name: String
    let includeArgumentParser: Bool
    let features: Set<CLIFeature>
    let author: String
    let licenseType: LicenseType

    // MARK: - Backward-Compatible Decoding

    enum CodingKeys: String, CodingKey {
        case name, includeArgumentParser, features, author, licenseType
    }

    init(
        name: String,
        includeArgumentParser: Bool,
        features: Set<CLIFeature>,
        author: String,
        licenseType: LicenseType = .apache2
    ) {
        self.name = name
        self.includeArgumentParser = includeArgumentParser
        self.features = features
        self.author = author
        self.licenseType = licenseType
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        includeArgumentParser = try container.decode(Bool.self, forKey: .includeArgumentParser)
        features = try container.decode(Set<CLIFeature>.self, forKey: .features)
        author = try container.decode(String.self, forKey: .author)
        licenseType = try container.decodeIfPresent(LicenseType.self, forKey: .licenseType) ?? .apache2
    }

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
