import Foundation
import Testing
@testable import MonolithLib

/// `ProjectOpener.target` picks the file `open` hands to `/usr/bin/open`;
/// testing it directly keeps the suite from launching anything.
struct ProjectOpenerTests {
    private func makeProject(named name: String) throws -> String {
        let path = NSTemporaryDirectory() + "monolith-opener-\(UUID().uuidString)/\(name)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    @Test
    func `a package opens its Package.swift`() throws {
        let project = try makeProject(named: "Pkg")
        defer { try? FileManager.default.removeItem(atPath: (project as NSString).deletingLastPathComponent) }
        #expect(ProjectOpener.target(at: project, projectSystem: .spm) == "\(project)/Package.swift")
    }

    @Test
    func `an app opens its xcodeproj`() throws {
        let project = try makeProject(named: "MyApp")
        defer { try? FileManager.default.removeItem(atPath: (project as NSString).deletingLastPathComponent) }
        try FileManager.default.createDirectory(atPath: "\(project)/MyApp.xcodeproj", withIntermediateDirectories: true)
        try "name: MyApp\n".write(toFile: "\(project)/project.yml", atomically: true, encoding: .utf8)
        for system in [ProjectSystem.xcodeProj, .xcodeGen] {
            #expect(ProjectOpener.target(at: project, projectSystem: system) == "\(project)/MyApp.xcodeproj")
        }
    }

    /// Before xcodegen runs, an XcodeGen app has only its spec.
    @Test
    func `an app without an xcodeproj opens its project.yml`() throws {
        let project = try makeProject(named: "MyApp")
        defer { try? FileManager.default.removeItem(atPath: (project as NSString).deletingLastPathComponent) }
        try "name: MyApp\n".write(toFile: "\(project)/project.yml", atomically: true, encoding: .utf8)
        #expect(ProjectOpener.target(at: project, projectSystem: .xcodeGen) == "\(project)/project.yml")
    }

    @Test
    func `an app with neither keeps the xcodeproj path`() throws {
        let project = try makeProject(named: "MyApp")
        defer { try? FileManager.default.removeItem(atPath: (project as NSString).deletingLastPathComponent) }
        #expect(ProjectOpener.target(at: project, projectSystem: .xcodeProj) == "\(project)/MyApp.xcodeproj")
    }
}
