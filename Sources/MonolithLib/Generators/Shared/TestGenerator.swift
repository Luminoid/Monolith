import Foundation

enum TestGenerator {

    /// Generate a Swift Testing test file.
    static func generate(suiteName: String, targetName: String) -> String {
        """
        import Foundation
        import Testing
        @testable import \(targetName)

        @Suite("\(suiteName)")
        struct \(suiteName)Tests {

            @Test("placeholder test")
            func placeholder() {
                #expect(true)
            }
        }
        """
    }
}
