import Foundation

/// Everything `monolith add <feature>` does to a project, worked out before
/// anything touches the disk. `--dry-run` prints it; a real run carries it
/// out. Both read the same list, so the preview can't drift from the writes.
///
/// A real run edits project.yml and merges entitlements in memory first and
/// writes only once both succeeded, so a failed `add` leaves the project as
/// it was.
struct AddPlan {
    enum Write {
        /// One new file. Kept when it exists, unless `--force`.
        case file(path: String, content: String, executable: Bool)
        /// Files written by a `FileWriter` group helper (tooling, git hook,
        /// LICENSE + CHANGELOG) under the same keep-or-overwrite policy.
        case group(paths: [String], write: (FileWriter.ExistingFilePolicy) throws -> Void)
        /// An entitlements plist that gains `additions` (created when
        /// missing). Merged, never replaced, even with `--force`.
        case entitlements(path: String, additions: [String: Any], summary: String)
    }

    let featureName: String
    var writes: [Write] = []
    /// The project.yml edit, applied to XcodeGen projects.
    var yamlEdit: ((inout String) -> ProjectYamlEditor.Result)?
    /// Printed for `.xcodeproj` projects in place of the project.yml edit.
    var manualSteps: [String] = []
    /// Printed after a real run (next steps, hints).
    var notes: [String] = []
    /// Printed through `Console.warn` by both a real run and a dry run.
    var warnings: [String] = []

    /// The paths of every `Write`, in order.
    var paths: [String] {
        writes.flatMap { write -> [String] in
            switch write {
            case let .file(path, _, _): [path]
            case let .group(paths, _): paths
            case let .entitlements(path, _, _): [path]
            }
        }
    }
}

// MARK: - Running

extension AddPlan {
    /// Carry the plan out in `projectDir`.
    func execute(in projectDir: String, projectSystem: ProjectSystem?, policy: FileWriter.ExistingFilePolicy) throws {
        let yaml = try editedYaml(in: projectDir, projectSystem: projectSystem)
        let merges = try mergedEntitlements(in: projectDir)

        for (index, write) in writes.enumerated() {
            switch write {
            case let .file(path, content, executable):
                try FileWriter.writeFile(at: path, content: content, basePath: projectDir, executable: executable, ifExists: policy)
            case let .group(_, writeGroup):
                try writeGroup(policy)
            case let .entitlements(path, _, summary):
                guard let merge = merges[index] else { continue }
                if merge.changed {
                    let fullPath = (projectDir as NSString).appendingPathComponent(path)
                    try FileManager.default.createDirectory(
                        atPath: (fullPath as NSString).deletingLastPathComponent,
                        withIntermediateDirectories: true
                    )
                    try merge.content.write(toFile: fullPath, atomically: true, encoding: .utf8)
                    print("  \(UISymbols.check) \(path) (\(merge.existed ? "merged" : "created"): \(summary))")
                } else {
                    print("  \(UISymbols.cycle) \(path) already has \(summary)")
                }
            }
        }

        if let yaml {
            switch yaml.result {
            case .applied:
                try yaml.content.write(toFile: Self.yamlPath(in: projectDir), atomically: true, encoding: .utf8)
                print("  \(UISymbols.check) project.yml updated (\(featureName))")
                print()
                print("  Re-run `xcodegen generate` to apply.")
            default:
                print("  \(UISymbols.cycle) project.yml already declares \(featureName); no change")
            }
        } else if !manualSteps.isEmpty {
            print()
            print("  Manual integration steps for \(featureName) (.xcodeproj):")
            for (index, step) in manualSteps.enumerated() {
                print("    \(index + 1). \(step)")
            }
        }

        if !notes.isEmpty {
            print()
            for note in notes {
                print(note.isEmpty ? "" : "  \(note)")
            }
        }
        printWarnings()
    }

    /// Say what a real run would do, per file, without writing anything.
    /// Throws when the real run would fail (project.yml can't be edited, an
    /// entitlements file can't be read).
    func printDryRun(in projectDir: String, projectSystem: ProjectSystem?, force: Bool) throws {
        let yaml = try editedYaml(in: projectDir, projectSystem: projectSystem)
        let merges = try mergedEntitlements(in: projectDir)

        print("  Dry run (nothing is written):")
        for (index, write) in writes.enumerated() {
            switch write {
            case let .file(path, _, _):
                print("    \(path): \(Self.fileStatus(path, in: projectDir, force: force))")
            case let .group(paths, _):
                for path in paths {
                    print("    \(path): \(Self.fileStatus(path, in: projectDir, force: force))")
                }
            case let .entitlements(path, _, summary):
                guard let merge = merges[index] else { continue }
                let status = !merge.existed ? "would create (\(summary))" : merge.changed ? "would merge \(summary)" : "already has \(summary)"
                print("    \(path): \(status)")
            }
        }
        if let yaml {
            print("    project.yml: \(yaml.result == .applied ? "would update" : "already up to date")")
        } else if !manualSteps.isEmpty {
            print("    (.xcodeproj: \(manualSteps.count) manual integration step\(manualSteps.count == 1 ? "" : "s") would follow)")
        }
        printWarnings()
    }

    private func printWarnings() {
        guard !warnings.isEmpty else { return }
        Console.printError("")
        for warning in warnings {
            Console.warn(warning)
        }
    }

    private static func fileStatus(_ path: String, in projectDir: String, force: Bool) -> String {
        let exists = FileManager.default.fileExists(atPath: (projectDir as NSString).appendingPathComponent(path))
        if !exists { return "would write" }
        return force ? "exists, would overwrite" : "exists, would skip"
    }

    private static func yamlPath(in projectDir: String) -> String {
        (projectDir as NSString).appendingPathComponent("project.yml")
    }

    /// project.yml after the edit, for XcodeGen projects with a plan that edits it.
    private func editedYaml(in projectDir: String, projectSystem: ProjectSystem?) throws -> (content: String, result: ProjectYamlEditor.Result)? {
        let path = Self.yamlPath(in: projectDir)
        guard projectSystem == .xcodeGen, let yamlEdit, FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        var yaml = try String(contentsOfFile: path, encoding: .utf8)
        let result = yamlEdit(&yaml)
        if case let .failed(reason) = result {
            throw ProjectYamlEditError(description: """
            project.yml could not be updated for \(featureName): \(reason). Nothing was written. \
            Edit project.yml by hand (or fix it and re-run `monolith add`), then run `xcodegen generate`.
            """)
        }
        return (yaml, result)
    }

    /// Each entitlements write's merged content, keyed by its index in `writes`.
    private func mergedEntitlements(in projectDir: String) throws -> [Int: (content: String, changed: Bool, existed: Bool)] {
        var merges: [Int: (content: String, changed: Bool, existed: Bool)] = [:]
        for (index, write) in writes.enumerated() {
            guard case let .entitlements(path, additions, _) = write else { continue }
            let segments = path.split(separator: "/", omittingEmptySubsequences: false)
            if path.hasPrefix("/") || path.contains("$") || segments.contains("..") {
                throw EntitlementsMerger.MergeError(description: """
                The app's entitlements are set to \(path), which `add` can't resolve inside the project, so nothing was written. \
                Point CODE_SIGN_ENTITLEMENTS at a path in the project, or add the keys by hand.
                """)
            }
            let fullPath = (projectDir as NSString).appendingPathComponent(path)
            let existing = FileManager.default.fileExists(atPath: fullPath)
                ? try String(contentsOfFile: fullPath, encoding: .utf8)
                : nil
            let merged = try EntitlementsMerger.merge(additions, into: existing, path: path)
            merges[index] = (merged.content, merged.changed, existing != nil)
        }
        return merges
    }
}

/// `add` could not wire a feature into project.yml, so it wrote nothing.
struct ProjectYamlEditError: Error, CustomStringConvertible {
    let description: String
}
