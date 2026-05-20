import Testing
@testable import MonolithLib

struct MonolithTests {
    @Test
    func `version is 0.2.0`() {
        #expect(Monolith.configuration.version == "0.2.0")
    }
}
