import Foundation

/// Serialization wrapper for saving/loading project configs to/from JSON.
enum ConfigFile {
    /// A union type that holds any project config for serialization.
    struct MonolithConfig: Codable, Sendable {
        let projectType: ProjectType
        let app: AppConfig?
        let package: PackageConfig?
        let cli: CLIConfig?
        let initGit: Bool
    }

    /// Save a config to a JSON file.
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
        print("  \u{2713} Config saved to \(path)")
    }

    /// Load a config from a JSON file.
    static func load(from path: String) throws -> MonolithConfig {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        return try decoder.decode(MonolithConfig.self, from: data)
    }
}
