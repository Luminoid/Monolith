import Foundation
import Testing
@testable import MonolithLib

struct ProjectDetectorTests {
    private func withTempDir(body: (String) throws -> Void) throws {
        let dir = NSTemporaryDirectory() + "monolith-detect-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try body(dir)
    }

    // MARK: - Detection

    @Test
    func `no project files throws noProjectFound`() throws {
        try withTempDir { dir in
            #expect(throws: (any Error).self) {
                _ = try ProjectDetector.detect(at: dir)
            }
        }
    }

    @Test
    func `LumiKit's UI product in any manifest marks a LumiKit app`() throws {
        try withTempDir { dir in
            #expect(!ProjectDetector.linksLumiKitUI(at: dir), "no manifest")
            try "packages:\n  SnapKit:\n    url: x\n".write(toFile: "\(dir)/project.yml", atomically: true, encoding: .utf8)
            #expect(!ProjectDetector.linksLumiKitUI(at: dir))
            try "dependencies:\n  - package: LumiKit\n    product: LumiKitUI\n".write(toFile: "\(dir)/project.yml", atomically: true, encoding: .utf8)
            #expect(ProjectDetector.linksLumiKitUI(at: dir))
        }
        try withTempDir { dir in
            try ".product(name: \"LumiKitUI\", package: \"LumiKit\")".write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)
            #expect(ProjectDetector.linksLumiKitUI(at: dir))
        }
        try withTempDir { dir in
            try FileManager.default.createDirectory(atPath: "\(dir)/App.xcodeproj", withIntermediateDirectories: true)
            try "productName = LumiKitUI;".write(toFile: "\(dir)/App.xcodeproj/project.pbxproj", atomically: true, encoding: .utf8)
            #expect(ProjectDetector.linksLumiKitUI(at: dir))
        }
    }

    @Test
    func `project.yml detected as app with xcodeGen`() throws {
        try withTempDir { dir in
            try "".write(toFile: "\(dir)/project.yml", atomically: true, encoding: .utf8)
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.type == .app)
            #expect(detected.projectSystem == .xcodeGen)
        }
    }

    @Test
    func `Package.swift with library target detected as package`() throws {
        try withTempDir { dir in
            let pkg = """
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(
                name: "MyLib",
                targets: [.target(name: "MyLib")]
            )
            """
            try pkg.write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.type == .package)
            #expect(detected.name == "MyLib")
        }
    }

    @Test
    func `Package.swift with executableTarget detected as cli`() throws {
        try withTempDir { dir in
            let pkg = """
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(
                name: "mytool",
                targets: [.executableTarget(name: "mytool")]
            )
            """
            try pkg.write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.type == .cli)
            #expect(detected.name == "mytool")
        }
    }

    @Test
    func `Package.swift with an executable beside library products is a package`() throws {
        try withTempDir { dir in
            let pkg = """
            // swift-tools-version: 6.2
            import PackageDescription
            let package = Package(
                name: "MultiLib",
                products: [
                    .library(name: "MultiLibCore", targets: ["MultiLibCore"]),
                    .executable(name: "multilib-tool", targets: ["multilib-tool"]),
                ],
                targets: [
                    .target(name: "MultiLibCore"),
                    .executableTarget(name: "multilib-tool", dependencies: ["MultiLibCore"]),
                ]
            )
            """
            try pkg.write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.type == .package)
            #expect(detected.name == "MultiLib")
        }
    }

    @Test
    func `a CLI that exports only its command library is still a cli`() {
        let manifest = """
        let package = Package(
            name: "my-tool",
            products: [
                .executable(name: "my-tool", targets: ["my-tool"]),
                .library(name: "MyToolKit", targets: ["MyToolKit"]),
            ],
            targets: [
                .target(name: "MyToolKit"),
                .executableTarget(name: "my-tool", dependencies: ["MyToolKit"]),
            ]
        )
        """
        #expect(ProjectDetector.isCommandLineTool(manifest: manifest))
        let withOtherLibrary = manifest.replacingOccurrences(of: "\"MyToolKit\", targets", with: "\"OtherLib\", targets")
        #expect(!ProjectDetector.isCommandLineTool(manifest: withOtherLibrary))
    }

    /// Apps can't be SPM executables (`new app` rejects that), so an
    /// executable target with app-like sources is still a command-line tool.
    @Test
    func `Package.swift with only an executable target is a cli even with app-like sources`() throws {
        try withTempDir { dir in
            let pkg = """
            let package = Package(
                name: "MyApp",
                targets: [.executableTarget(name: "MyApp")]
            )
            """
            try pkg.write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)
            let appDir = "\(dir)/Sources/MyApp/App"
            try FileManager.default.createDirectory(atPath: appDir, withIntermediateDirectories: true)
            try "".write(toFile: "\(appDir)/AppDelegate.swift", atomically: true, encoding: .utf8)

            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.type == .cli)
            #expect(detected.projectSystem == nil)
        }
    }

    /// An unreadable manifest is an unknown project; guessing "package" would
    /// let `add` write into a project it cannot see.
    @Test
    func `unreadable Package.swift throws instead of detecting a package`() throws {
        // Root ignores permission bits; nothing to check there.
        guard getuid() != 0 else { return }
        try withTempDir { dir in
            let manifest = "\(dir)/Package.swift"
            try "let package = Package(name: \"MyLib\")".write(toFile: manifest, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: manifest)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: manifest) }

            #expect(throws: ProjectDetector.DetectionError.self) {
                _ = try ProjectDetector.detect(at: dir)
            }
        }
    }

    // MARK: - Name Detection

    @Test
    func `name extracted from Package.swift`() throws {
        try withTempDir { dir in
            let pkg = """
            let package = Package(name: "HelloWorld", targets: [.target(name: "HelloWorld")])
            """
            try pkg.write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.name == "HelloWorld")
        }
    }

    @Test
    func `fallback to directory name when project.yml has no name`() throws {
        try withTempDir { dir in
            try "# empty".write(toFile: "\(dir)/project.yml", atomically: true, encoding: .utf8)
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.name == (dir as NSString).lastPathComponent)
        }
    }

    @Test
    func `XcodeGen app name comes from project.yml, not the directory`() throws {
        try withTempDir { dir in
            try "name: MyApp  # app\n\ntargets:\n  MyApp:\n    type: application\n".write(
                toFile: "\(dir)/project.yml", atomically: true, encoding: .utf8
            )
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.name == "MyApp")
            #expect(detected.projectSystem == .xcodeGen)
        }
    }

    @Test
    func `xcodeproj app name comes from the project bundle`() throws {
        try withTempDir { dir in
            try FileManager.default.createDirectory(atPath: "\(dir)/MyApp.xcodeproj", withIntermediateDirectories: true)
            let detected = try ProjectDetector.detect(at: dir)
            #expect(detected.name == "MyApp")
            #expect(detected.projectSystem == .xcodeProj)
        }
        try withTempDir { dir in
            // Several projects: the one with a matching source directory.
            for name in ["Alpha", "MyApp"] {
                try FileManager.default.createDirectory(atPath: "\(dir)/\(name).xcodeproj", withIntermediateDirectories: true)
            }
            try FileManager.default.createDirectory(atPath: "\(dir)/MyApp", withIntermediateDirectories: true)
            #expect(try ProjectDetector.detect(at: dir).name == "MyApp")
        }
    }

    @Test
    func `noProjectFound names the directory it searched`() throws {
        try withTempDir { dir in
            let error = #expect(throws: ProjectDetector.DetectionError.self) {
                _ = try ProjectDetector.detect(at: dir)
            }
            #expect(error?.description.contains(dir) == true)
        }
    }
}
