import Foundation
import Testing
@testable import MonolithLib

struct PackageResolverTests {
    @Test
    func `resolve at nonexistent directory fails gracefully`() {
        let result = PackageResolver.resolve(at: "/tmp/nonexistent-\(UUID().uuidString)")
        #expect(!result)
    }
}
