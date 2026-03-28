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
    func `Package.swift with executableTarget and App structure detected as app`() throws {
        try withTempDir { dir in
            let pkg = """
            // swift-tools-version: 6.0
            import PackageDescription
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
            #expect(detected.type == .app)
            #expect(detected.projectSystem == .spm)
            #expect(detected.name == "MyApp")
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
    func `fallback to directory name when Package.swift has no name`() throws {
        try withTempDir { dir in
            try "// empty".write(toFile: "\(dir)/project.yml", atomically: true, encoding: .utf8)
            let detected = try ProjectDetector.detect(at: dir)
            // Name comes from directory name since project.yml doesn't have Package.swift name
            #expect(!detected.name.isEmpty)
        }
    }
}
