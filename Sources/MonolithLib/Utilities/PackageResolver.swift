import Foundation

enum PackageResolver {
    /// Run `swift package resolve` in the given directory.
    @discardableResult
    static func resolve(at basePath: String) -> Bool {
        print("  Resolving packages...")
        return ShellRunner.runDiscardingOutput(
            executable: "/usr/bin/swift",
            arguments: ["package", "resolve"],
            cwd: basePath,
            successLabel: "Packages resolved",
            failureLabel: "Package resolve failed"
        )
    }
}
