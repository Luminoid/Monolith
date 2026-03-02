import Testing
@testable import MonolithLib

@Suite("Monolith")
struct MonolithTests {
    @Test("version is 0.1.0")
    func version() {
        #expect(Monolith.configuration.version == "0.1.0")
    }
}
