import Foundation
import Testing
@testable import MonolithLib

struct PackageResolverTests {
    @Test
    func `resolve spm at nonexistent directory fails gracefully`() {
        let result = PackageResolver.resolve(at: "/tmp/nonexistent-\(UUID().uuidString)", projectSystem: .spm)
        #expect(!result)
    }

    @Test
    func `resolve xcodeProj without generated xcodeproj skips gracefully`() {
        // App project where xcodegen hasn't produced the .xcodeproj yet (test
        // env without xcodegen installed) — resolve should bail with a
        // warning rather than invoke xcodebuild against a missing project.
        let tempDir = "/tmp/monolith-resolve-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let result = PackageResolver.resolve(at: tempDir, projectSystem: .xcodeGen)
        #expect(!result)
    }
}
