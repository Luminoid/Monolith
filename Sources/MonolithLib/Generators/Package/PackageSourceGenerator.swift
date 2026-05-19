enum PackageSourceGenerator {
    /// Generate a placeholder source file for a target.
    static func generateSource(targetName: String) -> String {
        """
        /// \(targetName) module placeholder. Add real public types here.
        public enum \(targetName) {}

        """
    }
}
