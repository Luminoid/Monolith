import Foundation

enum TestGenerator {
    /// Generate a Swift Testing test file with @testable import.
    ///
    /// Emits an empty `@Suite` struct rather than a `placeholder()` test that
    /// asserts `Bool(true) == true` — content-free tests inflate the test
    /// count without contributing signal and trick adopters into thinking
    /// coverage exists. The empty body is itself the prompt to write the
    /// first real test; no reminder-comment line is needed (SwiftLint's
    /// `todo` rule is on by default in the generated config, so any such
    /// comment would fail `make check` on the first run of a freshly
    /// scaffolded package).
    static func generate(suiteName: String, targetName: String) -> String {
        """
        import Foundation
        import Testing
        @testable import \(targetName)

        @Suite("\(suiteName)")
        struct \(suiteName)Tests {}

        """
    }

    /// Generate a simple test file without @testable import (e.g., for app test targets).
    static func generateAppTest(suiteName: String) -> String {
        """
        import Foundation
        import Testing

        @Suite("\(suiteName)")
        struct \(suiteName)Tests {}

        """
    }
}
