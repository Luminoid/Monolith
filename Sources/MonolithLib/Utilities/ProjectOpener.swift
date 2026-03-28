import Foundation

enum ProjectOpener {
    /// Open the appropriate project file after generation.
    @discardableResult
    static func open(at basePath: String, projectSystem: ProjectSystem) -> Bool {
        let projectName = (basePath as NSString).lastPathComponent

        let fileToOpen = switch projectSystem {
        case .xcodeProj, .xcodeGen: "\(projectName).xcodeproj"
        case .spm: "Package.swift"
        }

        let fullPath = (basePath as NSString).appendingPathComponent(fileToOpen)

        // Fallback: xcodeproj may not exist yet if xcodegen hasn't run
        let resolvedPath: String
        if projectSystem != .spm, !FileManager.default.fileExists(atPath: fullPath) {
            let ymlPath = (basePath as NSString).appendingPathComponent("project.yml")
            resolvedPath = FileManager.default.fileExists(atPath: ymlPath) ? ymlPath : fullPath
        } else {
            resolvedPath = fullPath
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
