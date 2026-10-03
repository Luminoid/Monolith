import Foundation

enum XcodeGenRunner {
    /// Run `xcodegen generate` in the given directory to produce a .xcodeproj.
    /// Warns on stderr when it fails: the install hint when xcodegen isn't on
    /// `PATH`, otherwise xcodegen's own output (a spec error, for example).
    @discardableResult
    static func generate(at basePath: String) -> Bool {
        guard ToolChecker.whichPath(for: "xcodegen") != nil else {
            Console.warn("xcodegen not found. Install with: brew install xcodegen")
            return false
        }
        return ShellRunner.runDiscardingOutput(
            executable: "/usr/bin/env",
            arguments: ["xcodegen", "generate"],
            cwd: basePath,
            successLabel: "Generated .xcodeproj",
            failureLabel: "xcodegen failed"
        )
    }
}
