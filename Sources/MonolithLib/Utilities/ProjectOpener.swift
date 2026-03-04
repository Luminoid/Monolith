import Foundation

enum ProjectOpener {
    /// Open the appropriate project file after generation.
    @discardableResult
    static func open(at basePath: String, projectSystem: ProjectSystem) -> Bool {
        let fileToOpen = switch projectSystem {
        case .spm: "Package.swift"
        case .xcodeGen: "project.xcodeproj"
        }

        let fullPath = (basePath as NSString).appendingPathComponent(fileToOpen)

        // Fallback to Package.swift if xcodeproj doesn't exist
        let needsFallback = projectSystem == .xcodeGen && !FileManager.default.fileExists(atPath: fullPath)
        let resolvedPath = if needsFallback {
            (basePath as NSString).appendingPathComponent("Package.swift")
        } else {
            fullPath
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [resolvedPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            print("  \u{2713} Opened \((resolvedPath as NSString).lastPathComponent)")
            return true
        } catch {
            return false
        }
    }
}
