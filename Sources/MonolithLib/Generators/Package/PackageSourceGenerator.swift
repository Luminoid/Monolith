enum PackageSourceGenerator {

    /// Generate a placeholder source file for a target.
    static func generateSource(targetName: String) -> String {
        """
        /// \(targetName) — placeholder module.
        public enum \(targetName) {}

        """
    }

    /// Generate a placeholder test file for a target.
    static func generateTest(targetName: String) -> String {
        """
        import Foundation
        import Testing
        @testable import \(targetName)

        @Suite("\(targetName)")
        struct \(targetName)Tests {
            @Test("placeholder test")
            func placeholder() {
                #expect(true)
            }
        }

        """
    }
}
