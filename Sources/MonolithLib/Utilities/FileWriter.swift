import Foundation

/// Writes project files. The `--dry-run` preview lives in `DryRunPlanner`,
/// and the git calls in `GitRunner`.
enum FileWriter {
    /// What `writeFile` does when the target file already exists.
    enum ExistingFilePolicy {
        /// Replace it. `new` writes into a fresh (or `--force`d) directory.
        case overwrite
        /// Keep it and say so. `add` runs against a project the user has
        /// already edited, so it never replaces a file without `--force`.
        case skip
    }

    /// Whether `writeFile` wrote the file or kept an existing one.
    enum WriteOutcome {
        case written
        case skipped
    }

    /// Write a file at the given relative path under the base directory.
    /// Creates intermediate directories as needed. Optionally sets executable permission.
    /// While `new` generates, a Ctrl-C makes the next call throw
    /// `SignalHandler.InterruptedError` instead of writing.
    @discardableResult
    static func writeFile(
        at relativePath: String,
        content: String,
        basePath: String,
        executable: Bool = false,
        ifExists policy: ExistingFilePolicy = .overwrite
    ) throws -> WriteOutcome {
        // Reject absolute paths and any segment that walks above the basePath.
        // Every current caller hardcodes a literal relative path (e.g.
        // "Sources/Foo.swift"), so a `..` or leading `/` is always a bug —
        // probably a missing trim of an absolute basePath that got passed
        // through as the relative arg. Catching it here keeps generators from
        // silently writing outside the project root if a future feature ever
        // surfaces user-supplied paths (e.g. a `--output-path <file>` knob).
        let segments = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        if relativePath.hasPrefix("/") || segments.contains("..") {
            throw FileWriterError.invalidRelativePath(relativePath)
        }
        if SignalHandler.guardsWrites {
            try SignalHandler.throwIfInterrupted()
        }
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        if policy == .skip, FileManager.default.fileExists(atPath: fullPath) {
            print("  \(UISymbols.cycle) \(relativePath) exists, kept")
            return .skipped
        }
        let directory = (fullPath as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try content.write(toFile: fullPath, atomically: true, encoding: .utf8)

        if executable {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: fullPath
            )
        }

        print("  \(UISymbols.check) \(relativePath)")
        return .written
    }

    /// Resolve the output base path: currentDirectory/projectName.
    static func resolveOutputPath(projectName: String, outputDir: String? = nil) -> String {
        let base = outputDir ?? FileManager.default.currentDirectoryPath
        return (base as NSString).appendingPathComponent(projectName)
    }

    // MARK: - Shared File Groups

    /// Write dev tooling files (.swiftlint.yml, .swiftformat, Makefile, Brewfile).
    ///
    /// `hasDefaultIsolation` means "build and test through xcodebuild" (a
    /// package with MainActor default isolation or a UIKit-only product);
    /// without it a package or CLI Makefile uses `swift build` / `swift test`.
    /// `hasMacCatalyst` adds the app Makefile's Catalyst targets; `hasWidget`
    /// adds the widget sources to SwiftLint's `included` paths.
    static func writeToolingFiles(
        projectType: ProjectType,
        appName: String? = nil,
        hasRSwift: Bool = false,
        hasFastlane: Bool = false,
        hasGitHooks: Bool = false,
        hasDefaultIsolation: Bool = false,
        hasLocalization: Bool = false,
        hasAppIconValidation: Bool = false,
        projectSystem: ProjectSystem? = nil,
        basePath: String,
        xcodeBuildScheme: String? = nil,
        disableTestParallelism: Bool = false,
        hasMacCatalyst: Bool = false,
        hasWidget: Bool = false,
        ifExists policy: ExistingFilePolicy = .overwrite
    ) throws {
        try writeFile(
            at: ".swiftlint.yml",
            content: SwiftLintGenerator.generate(
                projectType: projectType, appName: appName,
                hasRSwift: hasRSwift, hasFastlane: hasFastlane,
                hasWidget: hasWidget
            ),
            basePath: basePath,
            ifExists: policy
        )
        try writeFile(
            at: ".swiftformat",
            content: SwiftFormatGenerator.generate(
                excludeExtras: SwiftLintGenerator.toolExcludes(appName: appName, hasRSwift: hasRSwift, hasFastlane: hasFastlane)
            ),
            basePath: basePath,
            ifExists: policy
        )
        try writeFile(
            at: "Makefile",
            content: MakefileGenerator.generate(
                projectType: projectType, appName: appName,
                hasFastlane: hasFastlane, hasGitHooks: hasGitHooks,
                hasDefaultIsolation: hasDefaultIsolation,
                hasLocalization: hasLocalization,
                hasAppIconValidation: hasAppIconValidation,
                projectSystem: projectSystem,
                xcodeBuildScheme: xcodeBuildScheme,
                disableTestParallelism: disableTestParallelism,
                hasMacCatalyst: hasMacCatalyst
            ),
            basePath: basePath,
            ifExists: policy
        )
        try writeFile(
            at: "Brewfile",
            content: BrewfileGenerator.generate(
                projectSystem: projectSystem, hasRSwift: hasRSwift
            ),
            basePath: basePath,
            ifExists: policy
        )
    }

    /// Write git hooks (pre-commit script).
    static func writeGitHooks(
        basePath: String,
        options: GitHooksGenerator.Options = .basic,
        ifExists policy: ExistingFilePolicy = .overwrite
    ) throws {
        try writeFile(
            at: "Scripts/git-hooks/pre-commit",
            content: GitHooksGenerator.generatePreCommitHook(options: options),
            basePath: basePath,
            executable: true,
            ifExists: policy
        )
    }

    /// Write optional CLAUDE.md, LICENSE, and CHANGELOG files. With
    /// `projectName`, the CHANGELOG's `[Unreleased]` heading links to the
    /// project's GitHub commits when the license and author allow one (see
    /// `LicenseChangelogGenerator.unreleasedURL`).
    static func writeOptionalFiles(
        claudeMDContent: String?,
        licenseAuthor: String?,
        licenseType: LicenseType = .mit,
        projectName: String? = nil,
        basePath: String,
        ifExists policy: ExistingFilePolicy = .overwrite
    ) throws {
        if let content = claudeMDContent {
            try writeFile(at: ".claude/CLAUDE.md", content: content, basePath: basePath, ifExists: policy)
        }
        if let author = licenseAuthor {
            try writeFile(
                at: "LICENSE",
                content: LicenseChangelogGenerator.generateLicense(author: author, type: licenseType),
                basePath: basePath,
                ifExists: policy
            )
            let unreleasedURL = projectName.flatMap {
                LicenseChangelogGenerator.unreleasedURL(author: author, name: $0, licenseType: licenseType)
            }
            try writeFile(
                at: "CHANGELOG.md",
                content: LicenseChangelogGenerator.generateChangelog(unreleasedURL: unreleasedURL),
                basePath: basePath,
                ifExists: policy
            )
        }
    }
}

enum FileWriterError: Error, CustomStringConvertible {
    case invalidRelativePath(String)

    var description: String {
        switch self {
        case let .invalidRelativePath(path):
            "FileWriter rejected path '\(path)': must be relative and contain no '..' segments"
        }
    }
}
