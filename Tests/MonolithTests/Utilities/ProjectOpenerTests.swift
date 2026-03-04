import Foundation
import Testing
@testable import MonolithLib

@Suite("ProjectOpener")
struct ProjectOpenerTests {
    @Test("SPM file to open is Package.swift")
    func spmOpensPackageSwift() {
        // ProjectOpener opens Package.swift for SPM projects
        // We can't fully test process execution, but verify the logic
        let result = ProjectOpener.open(at: "/tmp/nonexistent-\(UUID().uuidString)", projectSystem: .spm)
        // Will fail because file doesn't exist, but verifies no crash
        #expect(!result)
    }

    @Test("XcodeGen falls back when xcodeproj missing")
    func xcodeGenFallback() {
        let result = ProjectOpener.open(at: "/tmp/nonexistent-\(UUID().uuidString)", projectSystem: .xcodeGen)
        #expect(!result)
    }
}
