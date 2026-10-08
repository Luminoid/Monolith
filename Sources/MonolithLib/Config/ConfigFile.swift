import Foundation

/// Serialization wrapper for saving/loading project configs to/from JSON.
enum ConfigFile {
    /// The schema this release writes. A file without `schemaVersion` predates
    /// the key and reads as 0; a file newer than this is rejected.
    static let currentSchemaVersion = 1

    /// A union type that holds any project config for serialization.
    struct MonolithConfig: Codable {
        let projectType: ProjectType
        let app: AppConfig?
        let package: PackageConfig?
        let cli: CLIConfig?
        let initGit: Bool
        /// The file format version, `0` for files written before it was recorded.
        let schemaVersion: Int
        /// The Monolith release that wrote the file. Informational.
        let monolithVersion: String?

        init(
            projectType: ProjectType,
            app: AppConfig?,
            package: PackageConfig?,
            cli: CLIConfig?,
            initGit: Bool,
            schemaVersion: Int = ConfigFile.currentSchemaVersion,
            monolithVersion: String? = Monolith.configuration.version
        ) {
            self.projectType = projectType
            self.app = app
            self.package = package
            self.cli = cli
            self.initGit = initGit
            self.schemaVersion = schemaVersion
            self.monolithVersion = monolithVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            projectType = try container.decode(ProjectType.self, forKey: .projectType)
            app = try container.decodeIfPresent(AppConfig.self, forKey: .app)
            package = try container.decodeIfPresent(PackageConfig.self, forKey: .package)
            cli = try container.decodeIfPresent(CLIConfig.self, forKey: .cli)
            initGit = try container.decodeIfPresent(Bool.self, forKey: .initGit) ?? false
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
            monolithVersion = try container.decodeIfPresent(String.self, forKey: .monolithVersion)
        }
    }

    /// A config file that can't be used: unreadable, malformed, from a newer
    /// schema, or for another project type.
    struct LoadError: Error, CustomStringConvertible {
        let description: String
    }

    /// Save a config to a JSON file. Keys are sorted and sets are written as
    /// sorted arrays, so saving the same config twice gives identical bytes.
    static func save(_ config: MonolithConfig, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let directory = (path as NSString).deletingLastPathComponent
        if !directory.isEmpty {
            try FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true
            )
        }
        try data.write(to: URL(fileURLWithPath: path))
        print("  \(UISymbols.check) Config saved to \(path)")
    }

    /// Load a config from a JSON file.
    ///
    /// With `expecting`, the file's `projectType` must match and its section
    /// must be present, so `new package --load-config app.json` fails instead
    /// of reading the wrong section. Unknown top-level and config keys are
    /// reported on stderr and ignored. A decoding failure is rethrown as a
    /// `LoadError` naming the key path (`app.features[2]`).
    static func load(from path: String, expecting: ProjectType? = nil) throws -> MonolithConfig {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let config: MonolithConfig
        do {
            config = try JSONDecoder().decode(MonolithConfig.self, from: data)
        } catch let error as DecodingError {
            throw LoadError(description: "Config file '\(path)' is invalid: \(describe(error))")
        }

        guard config.schemaVersion <= currentSchemaVersion else {
            throw LoadError(
                description: "Config file '\(path)' uses schema version \(config.schemaVersion), "
                    + "but this Monolith reads up to version \(currentSchemaVersion). Upgrade Monolith to load it."
            )
        }
        if let expecting {
            guard config.projectType == expecting else {
                throw LoadError(
                    description: "Config file '\(path)' was saved for `monolith new \(config.projectType.rawValue)` (projectType '\(config.projectType.rawValue)'). "
                        + "Load it with 'monolith new \(config.projectType.rawValue) --load-config'."
                )
            }
        }

        for key in unknownKeys(in: data, projectType: config.projectType) {
            Console.warn("Config file '\(path)' has an unknown key '\(key)'; it is ignored.")
        }
        return config
    }

    /// Keys in `data` this release doesn't read: top-level keys, plus keys in
    /// the section for `projectType`. Dotted paths, sorted.
    static func unknownKeys(in data: Data, projectType: ProjectType) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let topLevel = Set(MonolithConfig.CodingKeys.allCases.map(\.rawValue))
        var unknown = root.keys.filter { !topLevel.contains($0) }

        let (sectionKey, known): (String, [String]) = switch projectType {
        case .app: (MonolithConfig.CodingKeys.app.rawValue, AppConfig.CodingKeys.allCases.map(\.rawValue))
        case .package: (MonolithConfig.CodingKeys.package.rawValue, PackageConfig.CodingKeys.allCases.map(\.rawValue))
        case .cli: (MonolithConfig.CodingKeys.cli.rawValue, CLIConfig.CodingKeys.allCases.map(\.rawValue))
        }
        if let section = root[sectionKey] as? [String: Any] {
            let knownSet = Set(known)
            unknown += section.keys.filter { !knownSet.contains($0) }.map { "\(sectionKey).\($0)" }
        }
        return unknown.sorted()
    }

    /// `DecodingError` as one line: the key path where decoding stopped and why.
    static func describe(_ error: DecodingError) -> String {
        func path(_ codingPath: [CodingKey]) -> String {
            let rendered = codingPath.reduce(into: "") { result, key in
                if let index = key.intValue {
                    result += "[\(index)]"
                } else {
                    result += result.isEmpty ? key.stringValue : ".\(key.stringValue)"
                }
            }
            return rendered.isEmpty ? "the top level" : "'\(rendered)'"
        }
        switch error {
        case let .keyNotFound(key, context):
            return "missing key '\(key.stringValue)' at \(path(context.codingPath))."
        case let .typeMismatch(type, context):
            return "\(path(context.codingPath)) should be \(type). \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "\(path(context.codingPath)) is null but should be \(type)."
        case let .dataCorrupted(context):
            return "\(path(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return "\(error)"
        }
    }
}

extension ConfigFile.MonolithConfig {
    /// Declared in an extension to stay within the nesting limit;
    /// `ConfigFile.unknownKeys` reads the top-level key list from it.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case projectType, app, package, cli, initGit, schemaVersion, monolithVersion
    }
}
