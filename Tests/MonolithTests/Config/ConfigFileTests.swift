import Foundation
import Testing
@testable import MonolithLib

@Suite("ConfigFile")
struct ConfigFileTests {
    private func withTempFile(body: (String) throws -> Void) throws {
        let path = NSTemporaryDirectory() + "monolith-config-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try body(path)
    }

    // MARK: - App Config Round Trip

    @Test("app config round-trips through JSON")
    func appConfigRoundTrip() throws {
        try withTempFile { path in
            let config = AppConfig(
                name: "TestApp",
                bundleID: "com.test.app",
                deploymentTarget: "18.0",
                platforms: [.iPhone, .iPad],
                projectSystem: .spm,
                tabs: [TabDefinition(name: "Home", icon: "house")],
                primaryColor: "#007AFF",
                features: [.swiftData, .darkMode],
                author: "Test",
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .app, app: config, package: nil, cli: nil, initGit: true,
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.projectType == .app)
            #expect(loaded.initGit == true)
            #expect(loaded.app?.name == "TestApp")
            #expect(loaded.app?.bundleID == "com.test.app")
            #expect(loaded.app?.platforms.contains(.iPhone) == true)
            #expect(loaded.app?.platforms.contains(.iPad) == true)
            #expect(loaded.app?.projectSystem == .spm)
            #expect(loaded.app?.tabs.count == 1)
            #expect(loaded.app?.tabs.first?.name == "Home")
            #expect(loaded.app?.features.contains(.swiftData) == true)
            #expect(loaded.app?.features.contains(.darkMode) == true)
        }
    }

    // MARK: - Package Config Round Trip

    @Test("package config round-trips through JSON")
    func packageConfigRoundTrip() throws {
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
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .package, app: nil, package: config, cli: nil, initGit: false,
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

    @Test("CLI config round-trips through JSON")
    func cliConfigRoundTrip() throws {
        try withTempFile { path in
            let config = CLIConfig(
                name: "mytool",
                includeArgumentParser: true,
                features: [.argumentParser, .devTooling],
                author: "Test",
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .cli, app: nil, package: nil, cli: config, initGit: true,
            )

            try ConfigFile.save(mono, to: path)
            let loaded = try ConfigFile.load(from: path)

            #expect(loaded.projectType == .cli)
            #expect(loaded.cli?.name == "mytool")
            #expect(loaded.cli?.includeArgumentParser == true)
            #expect(loaded.cli?.features.contains(.argumentParser) == true)
        }
    }

    // MARK: - Error Cases

    @Test("loading nonexistent file throws")
    func loadNonexistent() {
        #expect(throws: (any Error).self) {
            _ = try ConfigFile.load(from: "/tmp/nonexistent-monolith-config.json")
        }
    }

    @Test("saved JSON is valid and readable")
    func savedJsonIsReadable() throws {
        try withTempFile { path in
            let config = CLIConfig(
                name: "test", includeArgumentParser: false, features: [], author: "A",
            )
            let mono = ConfigFile.MonolithConfig(
                projectType: .cli, app: nil, package: nil, cli: config, initGit: false,
            )
            try ConfigFile.save(mono, to: path)

            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["projectType"] as? String == "cli")
        }
    }
}
