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
                author: "Test"
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
                author: "Test"
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
                author: "Test"
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

    // MARK: - Backward Compatibility

    @Test
    func `app config without licenseType defaults to proprietary`() throws {
        try withTempFile { path in
            // Simulate old JSON without licenseType field
            let json = """
            {
                "projectType": "app",
                "initGit": false,
                "app": {
                    "name": "OldApp",
                    "bundleID": "com.test.old",
                    "deploymentTarget": "18.0",
                    "platforms": ["iPhone"],
                    "projectSystem": "spm",
                    "tabs": [],
                    "primaryColor": "#007AFF",
                    "features": [],
                    "author": "Test"
                }
            }
            """
            try json.write(toFile: path, atomically: true, encoding: .utf8)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.app?.licenseType == .proprietary)
        }
    }

    @Test
    func `package config without licenseType defaults to mit`() throws {
        try withTempFile { path in
            let json = """
            {
                "projectType": "package",
                "initGit": false,
                "package": {
                    "name": "OldLib",
                    "platforms": [{"platform": "iOS", "version": "18.0"}],
                    "targets": [{"name": "Core", "dependencies": []}],
                    "features": [],
                    "mainActorTargets": [],
                    "author": "Test"
                }
            }
            """
            try json.write(toFile: path, atomically: true, encoding: .utf8)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.package?.licenseType == .mit)
        }
    }

    @Test
    func `CLI config without licenseType defaults to apache2`() throws {
        try withTempFile { path in
            let json = """
            {
                "projectType": "cli",
                "initGit": false,
                "cli": {
                    "name": "oldtool",
                    "includeArgumentParser": true,
                    "features": [],
                    "author": "Test"
                }
            }
            """
            try json.write(toFile: path, atomically: true, encoding: .utf8)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.cli?.licenseType == .apache2)
        }
    }

    // MARK: - Error Cases

    @Test
    func `loading nonexistent file throws`() {
        #expect(throws: (any Error).self) {
            _ = try ConfigFile.load(from: "/tmp/nonexistent-monolith-config.json")
        }
    }

    @Test
    func `saved JSON is valid and readable`() throws {
        try withTempFile { path in
            let config = CLIConfig(
                name: "test", includeArgumentParser: false, features: [], author: "A"
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
