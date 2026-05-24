import Foundation

enum PackageResolver {
    /// Resolve SPM dependencies after generation. Branches on project system
    /// because app projects don't have a top-level `Package.swift` —
    /// `swift package resolve` fails with "Could not find Package.swift" in
    /// that case. Apps go through `xcodebuild -resolvePackageDependencies`
    /// against the generated `.xcodeproj` instead.
    @discardableResult
    static func resolve(at basePath: String, projectSystem: ProjectSystem) -> Bool {
        print("  Resolving packages...")
        switch projectSystem {
        case .spm:
            return ShellRunner.runDiscardingOutput(
                executable: "/usr/bin/swift",
                arguments: ["package", "resolve"],
                cwd: basePath,
                successLabel: "Packages resolved",
                failureLabel: "Package resolve failed"
            )
        case .xcodeProj, .xcodeGen:
            let projectName = (basePath as NSString).lastPathComponent
            let projectPath = "\(basePath)/\(projectName).xcodeproj"
            // xcodegen path: project.yml is on disk but the `.xcodeproj`
            // doesn't exist yet (test env without xcodegen installed). Skip
            // resolve quietly — there's nothing for xcodebuild to act on.
            guard FileManager.default.fileExists(atPath: projectPath) else {
                print("  ⚠ Skipping resolve: \(projectName).xcodeproj not found (xcodegen may not have run)")
                return false
            }
            return ShellRunner.runDiscardingOutput(
                executable: "/usr/bin/xcrun",
                arguments: ["xcodebuild", "-resolvePackageDependencies", "-project", projectPath],
                cwd: basePath,
                successLabel: "Packages resolved",
                failureLabel: "Package resolve failed"
            )
        }
    }
}
