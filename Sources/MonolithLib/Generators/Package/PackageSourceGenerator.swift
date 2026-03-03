enum PackageSourceGenerator {
    /// Generate a placeholder source file for a target.
    static func generateSource(targetName: String) -> String {
        """
        /// \(targetName) — placeholder module.
        public enum \(targetName) {}

        """
    }
}
