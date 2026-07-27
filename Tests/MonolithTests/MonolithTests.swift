import Testing
@testable import MonolithLib

struct MonolithTests {
    @Test
    func `version is 0.5.0`() {
        #expect(Monolith.configuration.version == "0.5.0")
    }
}
