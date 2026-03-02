import Foundation

enum TestGenerator {

    /// Generate a Swift Testing test file with @testable import.
    static func generate(suiteName: String, targetName: String) -> String {
        """
        import Foundation
        import Testing
        @testable import \(targetName)

        @Suite("\(suiteName)")
        struct \(suiteName)Tests {

            @Test("\(suiteName.lowercased()) test")
            func placeholder() {
                #expect(true)
            }
        }
        """
    }

    /// Generate a simple test file without @testable import (e.g., for app test targets).
    static func generateAppTest(suiteName: String) -> String {
        """
        import Foundation
        import Testing

        @Suite("\(suiteName)")
        struct \(suiteName)Tests {

            @Test("app launches")
            func appLaunches() {
                // Add tests here
                #expect(true)
            }
        }
        """
    }
}
