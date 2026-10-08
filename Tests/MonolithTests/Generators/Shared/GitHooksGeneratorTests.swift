import Foundation
import Testing
@testable import MonolithLib

struct GitHooksGeneratorTests {
    @Test
    func `pre-commit hook has bash shebang`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.hasPrefix("#!/bin/bash"))
    }

    @Test
    func `pre-commit hook checks staged Swift files only`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("git diff --cached --name-only"))
        #expect(output.contains("'*.swift'"))
    }

    @Test
    func `pre-commit hook lists renamed files and separates paths with NUL`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("--diff-filter=ACMR"))
        #expect(!output.contains("--diff-filter=ACM "), "a renamed file is a changed file")
        #expect(output.contains("--name-only -z"))
        #expect(output.contains("tr -cd '\\0'"), "the literal must reach the script as backslash-zero")
        #expect(!output.contains("| xargs swift"), "a plain xargs splits a path at its spaces")
    }

    @Test
    func `pre-commit hook runs SwiftLint with strict mode`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("xargs -0 swiftlint lint --strict"))
    }

    @Test
    func `pre-commit hook runs SwiftFormat in lint mode`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("xargs -0 swiftformat --lint"))
    }

    @Test
    func `pre-commit hook exits early when no Swift files staged`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("exit 0"))
    }

    @Test
    func `pre-commit hook fails when a tool is missing`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("for tool in swiftlint swiftformat"))
        #expect(output.contains("command -v \"$tool\""))
        #expect(output.contains("not found"))
        #expect(output.contains("exit 1"))
        #expect(!output.contains("skipping"), "a skipped check reads as a passed one")
    }

    /// Monolith commits through the hook it hands out, so a change to the
    /// template reaches its own repository in the same commit.
    @Test
    func `Monolith's own hook is the template's output`() throws {
        // Tests/MonolithTests/Generators/Shared/<this file>: five levels below the repository root.
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 {
            root.deleteLastPathComponent()
        }
        let path = root.appendingPathComponent("Scripts/git-hooks/pre-commit").path
        // Absent when the sources were copied without the repository around them.
        guard FileManager.default.fileExists(atPath: path) else { return }

        let own = try String(contentsOfFile: path, encoding: .utf8)
        #expect(own == GitHooksGenerator.generatePreCommitHook())
    }

    // MARK: - Core Data Audit Hook

    @Test
    func `basic options omit the Core Data audit reminder`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(!output.contains("Core Data model change"))
        #expect(!output.contains("xcdatamodel"))
    }

    @Test
    func `Core Data audit option adds model-change reminder`() {
        let output = GitHooksGenerator.generatePreCommitHook(options: .withCoreDataAudit)
        #expect(output.contains("Core Data model change"))
        #expect(output.contains("*.xcdatamodel/contents"))
        #expect(output.contains("*.xcdatamodeld/.xccurrentversion"))
        #expect(output.contains("CloudKit"))
    }

    @Test
    func `Core Data audit reminder is non-blocking`() {
        let output = GitHooksGenerator.generatePreCommitHook(options: .withCoreDataAudit)
        // Reminder block should not call exit or fail the commit.
        // It only echoes a warning and continues to the lint section.
        let reminderEnd = output.range(of: "Production schema deployed via Dashboard")
        #expect(reminderEnd != nil)
        if let reminderEnd {
            let afterReminder = output[reminderEnd.upperBound...]
            #expect(afterReminder.contains("staged_swift_files()"))
        }
    }

    // MARK: - SwiftData Audit Hook

    @Test
    func `basic options omit the SwiftData audit reminder`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(!output.contains("SwiftData"))
        #expect(!output.contains("@Model"))
    }

    @Test
    func `SwiftData audit option watches model files and @Model edits`() {
        let output = GitHooksGenerator.generatePreCommitHook(options: .withSwiftDataAudit)
        #expect(output.contains("SwiftData model change detected"))
        #expect(output.contains("'*/Core/Models/*.swift'"))
        #expect(output.contains("-G'@Model'"))
        #expect(output.contains("removed or renamed"))
        #expect(!output.contains("xcdatamodel"), "the Core Data reminder is a separate option")
    }

    @Test
    func `SwiftData audit sits before the lint section`() throws {
        let output = GitHooksGenerator.generatePreCommitHook(options: .withSwiftDataAudit)
        let reminder = try #require(output.range(of: "SwiftData model change detected"))
        let lint = try #require(output.range(of: "staged_swift_files()"))
        #expect(reminder.upperBound < lint.lowerBound)
    }

    @Test
    func `app hook options follow the persistence layer`() {
        func config(_ features: Set<AppFeature>) -> AppConfig {
            AppConfig(
                name: "HookApp", bundleID: "com.test.hook", deploymentTarget: "18.0", platforms: [.iPhone],
                projectSystem: .xcodeGen, tabs: [], primaryColor: "#007AFF", features: features,
                author: "Test", licenseType: .proprietary
            )
        }
        let swiftData = AppProjectGenerator.hookOptions(for: config([.swiftData, .cloudKit, .gitHooks]))
        #expect(swiftData.swiftDataAudit && !swiftData.coreDataAudit)

        let coreData = AppProjectGenerator.hookOptions(for: config([.coreData, .cloudKit, .gitHooks]))
        #expect(coreData.coreDataAudit && !coreData.swiftDataAudit)

        let noSync = AppProjectGenerator.hookOptions(for: config([.swiftData, .gitHooks]))
        #expect(!noSync.coreDataAudit && !noSync.swiftDataAudit)

        let explicit = AppProjectGenerator.hookOptions(for: config([.coreDataAuditHook, .gitHooks]))
        #expect(explicit.coreDataAudit && !explicit.swiftDataAudit)
    }
}

// MARK: - Behavior

/// Runs the generated hook in a scratch repository, with stand-ins for the
/// two tools that write down what they were handed. String checks cannot tell
/// a script that mentions `xargs -0` from one that passes paths through whole.
struct GitHooksBehaviorTests {
    /// A scratch repository, the hook, and a directory of stand-in tools.
    private struct Fixture {
        let root: String
        let git: String

        var repository: String { root + "/repo" }
        var tools: String { root + "/bin" }
        var hook: String { root + "/pre-commit" }

        /// nil when git is not on the PATH (the test then has nothing to run).
        init?(options: GitHooksGenerator.Options = .basic) throws {
            guard let git = ShellRunner.runCapturingStdout(executable: "/usr/bin/which", arguments: ["git"]) else { return nil }
            self.git = git
            root = NSTemporaryDirectory() + "monolith-hook-\(UUID().uuidString)"
            let manager = FileManager.default
            try manager.createDirectory(atPath: root + "/repo", withIntermediateDirectories: true)
            try manager.createDirectory(atPath: root + "/bin", withIntermediateDirectories: true)
            try GitHooksGenerator.generatePreCommitHook(options: options).write(toFile: root + "/pre-commit", atomically: true, encoding: .utf8)
            try run(["init", "-q"])
        }

        func cleanUp() {
            try? FileManager.default.removeItem(atPath: root)
        }

        func run(_ arguments: [String]) throws {
            // A developer's own signing and identity settings must not decide whether a scratch commit works.
            let settings = ["-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false"]
            let output = try ShellRunner.run(executable: git, arguments: settings + arguments, cwd: repository, captureStderr: true)
            #expect(output.exitCode == 0, "git \(arguments.joined(separator: " ")) failed: \(output.stderr)")
        }

        func write(_ path: String, _ content: String = "let value = 1\n") throws {
            let fullPath = repository + "/" + path
            try FileManager.default.createDirectory(atPath: (fullPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
        }

        /// A stand-in that appends its arguments, one per line, to `<name>.log`.
        func installTool(_ name: String, exitCode: Int = 0) throws {
            let script = """
            #!/bin/bash
            printf '%s\\n' "$@" >> "\(root)/\(name).log"
            exit \(exitCode)

            """
            let path = tools + "/" + name
            try script.write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        }

        /// What the stand-in was handed, or nil when it never ran.
        func arguments(of name: String) -> [String]? {
            guard let log = try? String(contentsOfFile: "\(root)/\(name).log", encoding: .utf8) else { return nil }
            return log.split(separator: "\n").map(String.init)
        }

        /// The hook's result with only the stand-ins and the system tools on the PATH.
        func runHook() throws -> ShellRunner.Output {
            try ShellRunner.run(
                executable: "/usr/bin/env",
                arguments: ["PATH=\(tools):/usr/bin:/bin", "/bin/bash", hook],
                cwd: repository,
                captureStdout: true,
                captureStderr: true
            )
        }
    }

    @Test(arguments: [GitHooksGenerator.Options.basic, .withCoreDataAudit, .withSwiftDataAudit, .init(coreDataAudit: true, swiftDataAudit: true)])
    func `generated hook is syntactically valid bash`(options: GitHooksGenerator.Options) throws {
        let path = NSTemporaryDirectory() + "pre-commit-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try GitHooksGenerator.generatePreCommitHook(options: options).write(toFile: path, atomically: true, encoding: .utf8)

        let output = try ShellRunner.run(executable: "/bin/bash", arguments: ["-n", path], captureStderr: true)
        #expect(output.exitCode == 0, "bash -n failed: \(output.stderr)")
    }

    @Test
    func `staged Swift files reach both tools whole, renames included`() throws {
        guard let fixture = try Fixture() else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint")
        try fixture.installTool("swiftformat")

        try fixture.write("Old.swift")
        try fixture.write("Gone.swift", "let gone = 1\n")
        try fixture.run(["add", "-A"])
        try fixture.run(["commit", "-q", "--no-verify", "-m", "initial"])

        try fixture.run(["mv", "Old.swift", "Renamed.swift"])
        try fixture.run(["rm", "-q", "Gone.swift"])
        try fixture.write("My Sources/My File.swift", "let spaced = 1\n")
        try fixture.write("Notes.md", "notes\n")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode == 0, "hook failed: \(output.stderr)\n\(output.stdout)")
        #expect(output.stdout.contains("checking 2 staged Swift file(s)"))
        // The path with spaces is one argument, the rename is listed, the deletion and the note are not.
        #expect(fixture.arguments(of: "swiftlint") == ["lint", "--strict", "--quiet", "My Sources/My File.swift", "Renamed.swift"])
        #expect(fixture.arguments(of: "swiftformat") == ["--lint", "My Sources/My File.swift", "Renamed.swift"])
    }

    @Test
    func `a commit without Swift files leaves the tools alone`() throws {
        guard let fixture = try Fixture() else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint")
        try fixture.installTool("swiftformat")
        try fixture.write("Notes.md", "notes\n")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode == 0)
        #expect(fixture.arguments(of: "swiftlint") == nil)
        #expect(fixture.arguments(of: "swiftformat") == nil)
    }

    @Test
    func `a commit without Swift files passes even when the tools are missing`() throws {
        guard let fixture = try Fixture() else { return }
        defer { fixture.cleanUp() }
        try fixture.write("Notes.md", "notes\n")
        try fixture.run(["add", "-A"])

        #expect(try fixture.runHook().exitCode == 0)
    }

    @Test(arguments: ["swiftlint", "swiftformat"])
    func `a missing tool fails the commit and says which`(missing: String) throws {
        guard let fixture = try Fixture() else { return }
        defer { fixture.cleanUp() }
        for tool in ["swiftlint", "swiftformat"] where tool != missing {
            try fixture.installTool(tool)
        }
        try fixture.write("App.swift")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode == 1)
        #expect(output.stderr.contains("error: \(missing) not found"))
        #expect(fixture.arguments(of: "swiftlint") == nil, "nothing runs until both tools are there")
        #expect(fixture.arguments(of: "swiftformat") == nil)
    }

    @Test
    func `a lint failure fails the commit`() throws {
        guard let fixture = try Fixture() else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint", exitCode: 2)
        try fixture.installTool("swiftformat")
        try fixture.write("App.swift")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode != 0)
        #expect(!output.stdout.contains("all checks passed"))
        #expect(fixture.arguments(of: "swiftformat") == nil, "the hook stops at the first failure")
    }

    @Test
    func `a format failure fails the commit`() throws {
        guard let fixture = try Fixture() else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint")
        try fixture.installTool("swiftformat", exitCode: 1)
        try fixture.write("App.swift")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode != 0)
        #expect(!output.stdout.contains("all checks passed"))
    }

    @Test
    func `the Core Data reminder prints and the commit still goes through`() throws {
        guard let fixture = try Fixture(options: .withCoreDataAudit) else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint")
        try fixture.installTool("swiftformat")
        try fixture.write("App.xcdatamodeld/App.xcdatamodel/contents", "<model/>\n")
        try fixture.write("App.swift")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode == 0, "hook failed: \(output.stderr)\n\(output.stdout)")
        #expect(output.stdout.contains("Core Data model change detected"))
        #expect(output.stdout.contains("all checks passed"))
    }

    @Test
    func `the SwiftData reminder names staged model files and the commit still goes through`() throws {
        guard let fixture = try Fixture(options: .withSwiftDataAudit) else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint")
        try fixture.installTool("swiftformat")
        try fixture.write("App/Core/Models/Trip.swift", "import SwiftData\n")
        try fixture.write("App/Features/Elsewhere.swift", "@Model final class Stop {}\n")
        try fixture.write("App/Features/Plain.swift")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode == 0, "hook failed: \(output.stderr)\n\(output.stdout)")
        #expect(output.stdout.contains("SwiftData model change detected"))
        #expect(output.stdout.contains("    App/Core/Models/Trip.swift"))
        #expect(output.stdout.contains("    App/Features/Elsewhere.swift"), "an @Model line outside Core/Models counts")
        #expect(!output.stdout.contains("    App/Features/Plain.swift"), "a file without @Model is not listed")
        #expect(output.stdout.contains("all checks passed"))
    }

    @Test
    func `deleting a SwiftData model triggers the reminder`() throws {
        guard let fixture = try Fixture(options: .withSwiftDataAudit) else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint")
        try fixture.installTool("swiftformat")
        try fixture.write("App/Core/Models/Trip.swift", "@Model final class Trip {}\n")
        try fixture.run(["add", "-A"])
        try fixture.run(["commit", "-q", "--no-verify", "-m", "initial"])
        try fixture.run(["rm", "-q", "App/Core/Models/Trip.swift"])

        let output = try fixture.runHook()

        #expect(output.exitCode == 0, "hook failed: \(output.stderr)\n\(output.stdout)")
        #expect(output.stdout.contains("    App/Core/Models/Trip.swift"))
    }

    @Test
    func `a change outside the models leaves the SwiftData reminder quiet`() throws {
        guard let fixture = try Fixture(options: .withSwiftDataAudit) else { return }
        defer { fixture.cleanUp() }
        try fixture.installTool("swiftlint")
        try fixture.installTool("swiftformat")
        try fixture.write("App/Features/Plain.swift")
        try fixture.run(["add", "-A"])

        let output = try fixture.runHook()

        #expect(output.exitCode == 0)
        #expect(!output.stdout.contains("SwiftData model change"))
        #expect(output.stdout.contains("all checks passed"))
    }
}
