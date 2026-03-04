import Foundation
import Testing
@testable import MonolithLib

@Suite("PackageResolver")
struct PackageResolverTests {
    @Test("resolve at nonexistent directory fails gracefully")
    func resolveNonexistent() {
        let result = PackageResolver.resolve(at: "/tmp/nonexistent-\(UUID().uuidString)")
        #expect(!result)
    }
}
