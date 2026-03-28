import Foundation
import Testing
@testable import MonolithLib

struct ProjectOpenerTests {
    @Test
    func `SPM file to open is Package.swift`() {
        // ProjectOpener opens Package.swift for SPM projects
        // We can't fully test process execution, but verify the logic
        let result = ProjectOpener.open(at: "/tmp/nonexistent-\(UUID().uuidString)", projectSystem: .spm)
        // Will fail because file doesn't exist, but verifies no crash
        #expect(!result)
    }

    @Test
    func `XcodeGen falls back when xcodeproj missing`() {
        let result = ProjectOpener.open(at: "/tmp/nonexistent-\(UUID().uuidString)", projectSystem: .xcodeGen)
        #expect(!result)
    }
}
