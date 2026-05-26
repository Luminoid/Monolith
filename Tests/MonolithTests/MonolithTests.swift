import Testing
@testable import MonolithLib

struct MonolithTests {
    @Test
    func `version is 0.4.0`() {
        #expect(Monolith.configuration.version == "0.4.0")
    }
}
