import Foundation

enum XcodeGenRunner {
    /// Run `xcodegen generate` in the given directory to produce a .xcodeproj.
    @discardableResult
    static func generate(at basePath: String) -> Bool {
        ShellRunner.runDiscardingOutput(
            executable: "/usr/bin/env",
            arguments: ["xcodegen", "generate"],
            cwd: basePath,
            successLabel: "Generated .xcodeproj",
            failureLabel: "xcodegen failed. Install with: brew install xcodegen"
        )
    }
}
