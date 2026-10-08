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

    // MARK: - Compatibility

    private func load(_ json: String, expecting: ProjectType? = nil) throws -> ConfigFile.MonolithConfig {
        var result: ConfigFile.MonolithConfig?
        try withTempFile { path in
            try json.write(toFile: path, atomically: true, encoding: .utf8)
            result = try ConfigFile.load(from: path, expecting: expecting)
        }
        return try #require(result)
    }

    /// Regression: configs saved by 0.1.0 have no `licenseType` and failed
    /// with `keyNotFound`. Each kind falls back to its default license.
    @Test
    func `configs without licenseType load with each kind's default`() throws {
        let app = try load("""
        {"projectType": "app", "initGit": false, "app": {"name": "OldApp", "bundleID": "com.example.oldapp",
          "deploymentTarget": "18.0", "platforms": ["iPhone"], "projectSystem": "xcodeProj", "tabs": [],
          "primaryColor": "#007AFF", "features": [], "author": "Test"}}
        """)
        #expect(app.app?.licenseType == .proprietary)
        #expect(app.schemaVersion == 0)

        let package = try load("""
        {"projectType": "package", "initGit": false, "package": {"name": "OldLib",
          "platforms": [{"platform": "iOS", "version": "18.0"}], "targets": [{"name": "OldLib", "dependencies": []}],
          "features": [], "mainActorTargets": [], "author": "Test"}}
        """)
        #expect(package.package?.licenseType == .mit)

        let cli = try load("""
        {"projectType": "cli", "initGit": false, "cli": {"name": "oldtool", "includeArgumentParser": true, "features": [], "author": "Test"}}
        """)
        #expect(cli.cli?.licenseType == .apache2)
        #expect(cli.cli?.includeArgumentParser == true)
    }

    /// Regression: `"features": ["snapKit"]` failed with a raw `DecodingError`.
    @Test
    func `a removed feature alias in a config file gets the migration message and key path`() {
        let json = """
        {"projectType": "app", "initGit": false, "app": {"name": "OldApp", "bundleID": "com.example.oldapp",
          "deploymentTarget": "18.0", "platforms": ["iPhone"], "projectSystem": "xcodeProj", "tabs": [],
          "primaryColor": "#007AFF", "features": ["snapKit"], "author": "Test", "licenseType": "proprietary"}}
        """
        let error = #expect(throws: ConfigFile.LoadError.self) { try load(json) }
        #expect(error?.description.contains("'app.features'") == true)
        #expect(error?.description.contains("snapKit → --use-packages SnapKit") == true)
    }

    @Test
    func `an unknown feature in a config file names the key and a suggestion`() {
        let json = """
        {"projectType": "cli", "initGit": false, "cli": {"name": "tool", "features": ["devToolin"], "author": "Test", "licenseType": "mit"}}
        """
        let error = #expect(throws: ConfigFile.LoadError.self) { try load(json) }
        #expect(error?.description.contains("'cli.features'") == true)
        #expect(error?.description.contains("Did you mean 'devTooling'?") == true)
    }

    @Test
    func `a missing required key names its path`() {
        let json = """
        {"projectType": "cli", "initGit": false, "cli": {"features": [], "author": "Test"}}
        """
        let error = #expect(throws: ConfigFile.LoadError.self) { try load(json) }
        #expect(error?.description.contains("missing key 'name' at 'cli'") == true)
    }

    @Test
    func `unknown top-level and config keys are reported`() {
        let json = """
        {"projectType": "cli", "initGit": false, "bogus": 1, "cli": {"name": "tool", "features": [], "author": "Test", "extraField": true}}
        """
        #expect(ConfigFile.unknownKeys(in: Data(json.utf8), projectType: .cli) == ["bogus", "cli.extraField"])
    }

    /// Regression: `projectType` was decoded but never read.
    @Test
    func `a config for another project type is rejected`() {
        let json = """
        {"projectType": "cli", "initGit": false, "cli": {"name": "tool", "features": [], "author": "Test"}}
        """
        let error = #expect(throws: ConfigFile.LoadError.self) { try load(json, expecting: .package) }
        #expect(error?.description.contains("monolith new cli --load-config") == true)
    }

    @Test
    func `a config from a newer schema is rejected`() {
        let json = """
        {"projectType": "cli", "schemaVersion": 99, "initGit": false, "cli": {"name": "tool", "features": [], "author": "Test"}}
        """
        let error = #expect(throws: ConfigFile.LoadError.self) { try load(json) }
        #expect(error?.description.contains("schema version 99") == true)
    }

    @Test
    func `saved configs record the schema and Monolith versions`() throws {
        try withTempFile { path in
            let config = CLIConfig(name: "tool", features: [], author: "A", licenseType: .apache2)
            try ConfigFile.save(config.monolithConfig(initGit: false), to: path)
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any]
            #expect(json?["schemaVersion"] as? Int == ConfigFile.currentSchemaVersion)
            #expect(json?["monolithVersion"] as? String == Monolith.configuration.version)
        }
    }

    // MARK: - Determinism

    /// Regression: sets encoded in hash order, so four identical runs wrote
    /// four different files.
    @Test
    func `saved configs are byte-for-byte stable and sets are sorted`() throws {
        func appConfig(features: [AppFeature], platforms: [Platform]) -> AppConfig {
            var featureSet = Set<AppFeature>(minimumCapacity: 64)
            features.forEach { featureSet.insert($0) }
            return AppConfig(
                name: "StableApp",
                bundleID: "com.example.stableapp",
                deploymentTarget: "18.0",
                platforms: Set(platforms),
                projectSystem: .xcodeGen,
                tabs: [],
                primaryColor: "#007AFF",
                features: featureSet,
                author: "Test",
                licenseType: .proprietary
            )
        }
        let features: [AppFeature] = [.widget, .coreData, .lumiKit, .devTooling, .gitHooks, .cloudKit, .notifications]
        let forward = appConfig(features: features, platforms: [.iPhone, .iPad, .macCatalyst])
        let reversed = appConfig(features: features.reversed(), platforms: [.macCatalyst, .iPad, .iPhone])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let first = try encoder.encode(forward.monolithConfig(initGit: true))
        let second = try encoder.encode(reversed.monolithConfig(initGit: true))
        #expect(first == second)

        let json = try JSONSerialization.jsonObject(with: first) as? [String: Any]
        let app = json?["app"] as? [String: Any]
        #expect(app?["features"] as? [String] == features.map(\.rawValue).sorted())
        #expect(app?["platforms"] as? [String] == ["iPad", "iPhone", "macCatalyst"])

        let package = PackageConfig(
            name: "StableLib",
            platforms: [],
            targets: [TargetDefinition(name: "A", dependencies: []), TargetDefinition(name: "B", dependencies: [])],
            features: [.gitHooks, .devTooling, .claudeMD],
            mainActorTargets: ["B", "A"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["B", "A"]
        )
        let packageJSON = try JSONSerialization.jsonObject(with: encoder.encode(package)) as? [String: Any]
        // MainActor targets add `defaultIsolation`.
        #expect(packageJSON?["features"] as? [String] == ["claudeMD", "defaultIsolation", "devTooling", "gitHooks"])
        #expect(packageJSON?["mainActorTargets"] as? [String] == ["A", "B"])
        #expect(packageJSON?["testHelperTargets"] as? [String] == ["A", "B"])
    }
}
