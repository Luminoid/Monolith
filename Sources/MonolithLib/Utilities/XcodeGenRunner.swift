import Foundation

enum XcodeGenRunner {
    /// Run `xcodegen generate` in the given directory to produce a .xcodeproj.
    @discardableResult
    static func generate(at basePath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xcodegen", "generate"]
        process.currentDirectoryURL = URL(fileURLWithPath: basePath)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                print("  \u{26A0} xcodegen failed (exit \(process.terminationStatus)). Install with: brew install xcodegen")
                return false
            }
            print("  \u{2713} Generated .xcodeproj")
            return true
        } catch {
            print("  \u{26A0} xcodegen not found. Install with: brew install xcodegen")
            return false
        }
    }
}
