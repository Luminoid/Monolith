import Foundation
import Testing
@testable import MonolithLib

struct ConfigFileTests {
    private func withTempFile(body: (String) throws -> Void) throws {
        let path = NSTemporaryDirectory() + "monolith-config-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try body(path)
    }

    // MARK: - App Config Round Trip

    @Test
    func `app config round-trips through JSON`() throws {
        try withTempFile { path in
            let config = AppConfig(
                name: "TestApp",
                bundleID: "com.test.app",
                deploymentTarget: "18.0",
                platforms: [.iPhone, .iPad],
                projectSystem: .xcodeProj,
                tabs: [TabDefinition(name: "Home", icon: "house")],
                primaryColor: "#007AFF",
                features: [.swiftData, .darkMode],
                author: "Test",
                licenseType: .proprietary
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .app, app: config, package: nil, cli: nil, initGit: true
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.projectType == .app)
            #expect(loaded.initGit == true)
            #expect(loaded.app?.name == "TestApp")
            #expect(loaded.app?.bundleID == "com.test.app")
            #expect(loaded.app?.platforms.contains(.iPhone) == true)
            #expect(loaded.app?.platforms.contains(.iPad) == true)
            #expect(loaded.app?.projectSystem == .xcodeProj)
            #expect(loaded.app?.tabs.count == 1)
            #expect(loaded.app?.tabs.first?.name == "Home")
            #expect(loaded.app?.features.contains(.swiftData) == true)
            #expect(loaded.app?.features.contains(.darkMode) == true)
        }
    }

    // MARK: - Package Config Round Trip

    @Test
    func `package config round-trips through JSON`() throws {
        try withTempFile { path in
            let config = PackageConfig(
                name: "TestLib",
                platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                targets: [
                    TargetDefinition(name: "Core", dependencies: []),
                    TargetDefinition(name: "UI", dependencies: ["Core"]),
                ],
                features: [.strictConcurrency, .devTooling],
                mainActorTargets: ["UI"],
                author: "Test",
                licenseType: .mit
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .package, app: nil, package: config, cli: nil, initGit: false
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.projectType == .package)
            #expect(loaded.initGit == false)
            #expect(loaded.package?.name == "TestLib")
            #expect(loaded.package?.targets.count == 2)
            #expect(loaded.package?.targets[1].dependencies == ["Core"])
            #expect(loaded.package?.features.contains(.strictConcurrency) == true)
            #expect(loaded.package?.mainActorTargets.contains("UI") == true)
            // Both targets here default to library (isExecutable: false). Confirm
            // the encoded JSON doesn't lose this distinction across a round trip.
            #expect(loaded.package?.targets.allSatisfy { !$0.isExecutable } == true)
        }
    }

    @Test
    func `package config preserves executable targets across JSON round trip`() throws {
        try withTempFile { path in
            let config = PackageConfig(
                name: "TestLib",
                platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                targets: [
                    TargetDefinition(name: "TestLib", dependencies: []),
                    TargetDefinition(name: "test-tool", dependencies: ["TestLib"], isExecutable: true),
                ],
                features: [],
                mainActorTargets: [],
                author: "Test",
                licenseType: .mit
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .package, app: nil, package: config, cli: nil, initGit: false
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.package?.targets.first(where: { $0.name == "TestLib" })?.isExecutable == false)
            #expect(loaded.package?.targets.first(where: { $0.name == "test-tool" })?.isExecutable == true)
        }
    }

    @Test
    func `package config from pre-isExecutable JSON decodes with isExecutable false`() throws {
        // Backward compatibility: JSON written by an earlier Monolith version has
        // no "isExecutable" key on TargetDefinition. The custom decoder defaults
        // it to false so saved configs from before this change keep loading.
        let legacyJSON = """
        {
          "projectType": "package",
          "initGit": false,
          "package": {
            "name": "LegacyLib",
            "platforms": [{"platform": "iOS", "version": "18.0"}],
            "targets": [
              {"name": "LegacyLib", "dependencies": []}
            ],
            "features": [],
            "mainActorTargets": [],
            "author": "Test",
            "licenseType": "mit"
          }
        }
        """
        try withTempFile { path in
            try legacyJSON.write(toFile: path, atomically: true, encoding: .utf8)
            let loaded = try ConfigFile.load(from: path)
            #expect(loaded.package?.targets.first?.name == "LegacyLib")
            #expect(loaded.package?.targets.first?.isExecutable == false)
        }
    }

    // MARK: - CLI Config Round Trip

    @Test
    func `CLI config round-trips through JSON`() throws {
        try withTempFile { path in
            let config = CLIConfig(
                name: "mytool",
                includeArgumentParser: true,
                features: [.argumentParser, .devTooling],
                author: "Test",
                licenseType: .apache2
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .cli, app: nil, package: nil, cli: config, initGit: true
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.projectType == .cli)
            #expect(loaded.cli?.name == "mytool")
            #expect(loaded.cli?.includeArgumentParser == true)
            #expect(loaded.cli?.features.contains(.argumentParser) == true)
        }
    }

    // MARK: - License Type Round Trip

    @Test
    func `app config preserves license type through JSON`() throws {
        try withTempFile { path in
            let config = AppConfig(
                name: "TestApp",
                bundleID: "com.test.app",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeProj,
                tabs: [],
                primaryColor: "#007AFF",
                features: [.licenseChangelog],
                author: "Test",
                licenseType: .apache2
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .app, app: config, package: nil, cli: nil, initGit: false
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.app?.licenseType == .apache2)
        }
    }

    @Test
    func `package config preserves license type through JSON`() throws {
        try withTempFile { path in
            let config = PackageConfig(
                name: "TestLib",
                platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                targets: [TargetDefinition(name: "Core", dependencies: [])],
                features: [.licenseChangelog],
                mainActorTargets: [],
                author: "Test",
                licenseType: .proprietary
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .package, app: nil, package: config, cli: nil, initGit: false
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.package?.licenseType == .proprietary)
        }
    }

    @Test
    func `CLI config preserves license type through JSON`() throws {
        try withTempFile { path in
            let config = CLIConfig(
                name: "mytool",
                includeArgumentParser: true,
                features: [.licenseChangelog],
                author: "Test",
                licenseType: .mit
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .cli, app: nil, package: nil, cli: config, initGit: false
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.cli?.licenseType == .mit)
        }
    }

    // MARK: - Error Cases

    @Test
    func `loading nonexistent file throws`() {
        #expect(throws: (any Error).self) {
            _ = try ConfigFile.load(from: "/tmp/nonexistent-monolith-config.json")
        }
    }

    /// Exhaustive round-trip: every app `Feature` plus every nested array
    /// field (tabs, platforms) must survive save + load without loss. Guards
    /// against future regressions where a new `@Decodable` field is added to
    /// `AppConfig` but the encoder side is forgotten.
    @Test
    func `every app feature round-trips losslessly`() throws {
        try withTempFile { path in
            let allFeatures = Set(AppFeature.allCases)
            let config = AppConfig(
                name: "Everything",
                bundleID: "com.example.everything",
                deploymentTarget: "18.0",
                platforms: [.iPhone, .iPad, .macCatalyst],
                projectSystem: .xcodeGen,
                tabs: [
                    TabDefinition(name: "Home", icon: "house"),
                    TabDefinition(name: "Settings", icon: "gear"),
                ],
                primaryColor: "#4CAF7D",
                features: allFeatures,
                author: "Round Trip",
                licenseType: .apache2
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .app, app: config, package: nil, cli: nil, initGit: false
            )
            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            let restored = try #require(loaded.app)
            #expect(restored.name == config.name)
            #expect(restored.bundleID == config.bundleID)
            #expect(restored.platforms == config.platforms)
            #expect(restored.projectSystem == config.projectSystem)
            #expect(restored.tabs.count == config.tabs.count)
            #expect(restored.tabs.map(\.name) == config.tabs.map(\.name))
            #expect(restored.primaryColor == config.primaryColor)
            #expect(restored.features == config.features)
            #expect(restored.author == config.author)
            #expect(restored.licenseType == config.licenseType)
        }
    }

    @Test
    func `saved JSON is valid and readable`() throws {
        try withTempFile { path in
            let config = CLIConfig(
                name: "test", includeArgumentParser: false, features: [], author: "A", licenseType: .apache2
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .cli, app: nil, package: nil, cli: config, initGit: false
            )
            try ConfigFile.save(mono, to: path)

            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["projectType"] as? String == "cli")
        }
    }
}
