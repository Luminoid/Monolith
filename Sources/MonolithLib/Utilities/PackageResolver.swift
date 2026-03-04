import Foundation

enum PackageResolver {
    /// Run `swift package resolve` in the given directory.
    @discardableResult
    static func resolve(at basePath: String) -> Bool {
        print("  Resolving packages...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["package", "resolve"]
        process.currentDirectoryURL = URL(fileURLWithPath: basePath)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                print("  \u{26A0} Package resolve failed (exit \(process.terminationStatus))")
                return false
            }
            print("  \u{2713} Packages resolved")
            return true
        } catch {
            print("  \u{26A0} Package resolve failed: \(error.localizedDescription)")
            return false
        }
    }
}
