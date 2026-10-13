struct CLIConfig: Codable {
    let name: String
    let features: Set<CLIFeature>
    let author: String
    let licenseType: LicenseType

    init(name: String, features: Set<CLIFeature>, author: String, licenseType: LicenseType) {
        self.name = name
        self.features = features
        self.author = author
        self.licenseType = licenseType
    }

    /// For call sites that decide ArgumentParser separately from the other
    /// features: `true` adds `.argumentParser` to `features`, `false`
    /// removes it.
    init(name: String, includeArgumentParser: Bool, features: Set<CLIFeature>, author: String, licenseType: LicenseType) {
        self.init(
            name: name,
            features: includeArgumentParser ? features.union([.argumentParser]) : features.subtracting([.argumentParser]),
            author: author,
            licenseType: licenseType
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case name, features, author, licenseType
        /// Written by releases that stored the ArgumentParser choice twice.
        /// Still read (`true` adds `.argumentParser`) and still written, so
        /// those releases can load configs saved by this one.
        case includeArgumentParser
    }

    /// Custom decoder: `licenseType` falls back to the CLI default for configs
    /// saved before it existed, and an unknown feature name fails with a
    /// readable message.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var features = try container.decodeFeatures(CLIFeature.self, forKey: .features)
        if try container.decodeIfPresent(Bool.self, forKey: .includeArgumentParser) == true {
            features.insert(.argumentParser)
        }
        try self.init(
            name: container.decode(String.self, forKey: .name),
            features: features,
            author: container.decode(String.self, forKey: .author),
            licenseType: container.decodeIfPresent(LicenseType.self, forKey: .licenseType) ?? LicenseType.defaultFor(.cli)
        )
    }

    /// Features encode as a sorted array so a saved config is deterministic.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(features.sortedRawValues, forKey: .features)
        try container.encode(author, forKey: .author)
        try container.encode(licenseType, forKey: .licenseType)
        try container.encode(includeArgumentParser, forKey: .includeArgumentParser)
    }

    /// Whether the CLI is built on swift-argument-parser.
    var includeArgumentParser: Bool {
        features.contains(.argumentParser)
    }

    /// The command's Swift type name: `name` in UpperCamelCase, so a CLI named
    /// `my-tool` declares `struct MyTool`. The executable keeps `name`.
    var typeName: String {
        name.upperCamelCased
    }

    /// The library target that holds the command types. The `name` executable
    /// is a thin `main.swift` calling into it, so tests import the library
    /// instead of an executable module.
    var libraryName: String {
        "\(typeName)Kit"
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

extension CLIConfig: GeneratableConfig {
    static var projectType: ProjectType { .cli }

    /// The CLI name is also the executable, library, and test target stem.
    func validateForGeneration() throws {
        if let problem = Validators.projectNameProblem(name, kind: .cli) {
            throw ConfigValidationError(problem)
        }
    }

    func monolithConfig(initGit: Bool) -> ConfigFile.MonolithConfig {
        ConfigFile.MonolithConfig(projectType: .cli, app: nil, package: nil, cli: self, initGit: initGit)
    }
}
