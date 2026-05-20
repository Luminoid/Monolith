import Foundation

enum TestGenerator {
    /// Generate a Swift Testing test file with @testable import.
    ///
    /// Emits an empty `@Suite` struct rather than a `placeholder()` test that
    /// asserts `Bool(true) == true` — content-free tests inflate the test count
    /// without contributing signal and trick adopters into thinking coverage
    /// exists. The reminder line in the generated output IS the prompt to
    /// write the first real test; a freshly-scaffolded package should carry
    /// that nudge visibly in the source.
    static func generate(suiteName: String, targetName: String) -> String {
        """
        import Foundation
        import Testing
        @testable import \(targetName)

        // TODO: Add tests for \(targetName).
        @Suite("\(suiteName)")
        struct \(suiteName)Tests {}

        """
    }

    /// Generate a simple test file without @testable import (e.g., for app test targets).
    static func generateAppTest(suiteName: String) -> String {
        """
        import Foundation
        import Testing

        // TODO: Add tests for the app.
        @Suite("\(suiteName)")
        struct \(suiteName)Tests {}

        """
    }
}
