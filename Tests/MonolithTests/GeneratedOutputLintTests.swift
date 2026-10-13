import Foundation
import Testing
@testable import MonolithLib

/// SwiftLint and SwiftFormat on PATH, or nil when either is missing.
private let linters: (swiftlint: String, swiftformat: String)? = {
    func path(of tool: String) -> String? {
        ShellRunner.runCapturingStdout(executable: "/usr/bin/which", arguments: [tool])
    }
    guard let swiftlint = path(of: "swiftlint"), let swiftformat = path(of: "swiftformat") else { return nil }
    return (swiftlint, swiftformat)
}()

/// One `monolith new <kind>` run for `GeneratedOutputLintTests`. `flags`
/// follow `--name`; every app passes `--project-system xcodegen`, so nothing
/// invokes xcodegen.
struct LintFixture: CustomTestStringConvertible {
    enum Kind {
        case app, package, cli
    }

    let label: String
    let kind: Kind
    let name: String
    let flags: [String]
    /// For an app: whether its tests run one at a time.
    var runsTestsSerially = false

    var testDescription: String {
        label
    }
}

/// A matrix of generated project shapes, each rendered by the real `monolith
/// new` command (flags parsed, config built, generators run; no xcodegen),
/// then held to the SwiftLint and SwiftFormat gates its own `make check` runs.
///
/// Substring tests on single generators can't see a violation that only
/// appears in a whole file under the generated `.swiftlint.yml` and
/// `.swiftformat`, so a fresh scaffold could fail its own first `make check`.
/// The linters run before any build, as on a fresh clone: an Xcode build's
/// SwiftFormat phase rewrites the sources and would hide the problem.
///
/// Child of `MonolithIntegrationSuite` because `withTempDir` changes the
/// working directory and `new` installs a process-wide SIGINT handler.
extension MonolithIntegrationSuite {
    struct GeneratedOutputLintTests {
        static let fixtures: [LintFixture] = [
            LintFixture(label: "CLI, full preset", kind: .cli, name: "LintTool", flags: ["--preset", "full"]),
            LintFixture(label: "CLI, hyphenated name", kind: .cli, name: "my-tool", flags: ["--preset", "full"]),
            LintFixture(label: "package, full preset", kind: .package, name: "LintKit", flags: ["--preset", "full"]),
            LintFixture(label: "multi-target package", kind: .package, name: "MultiLib", flags: [
                "--targets", "MultiLibCore,MultiLibUI,MultiLibTesting,multilib-tool:exec",
                "--target-deps", "MultiLibUI:MultiLibCore;MultiLibTesting:MultiLibCore;multilib-tool:MultiLibCore",
                "--main-actor-targets", "MultiLibUI",
                "--test-helper-targets", "MultiLibTesting",
                "--platforms", "iOS 18.0",
                "--features", "defaultIsolation,devTooling,gitHooks,claudeMD,licenseChangelog",
            ]),
            LintFixture(label: "package on LumiKitUI", kind: .package, name: "LintUI", flags: [
                "--targets", "LintUI",
                "--target-deps", "LintUI:LumiKitUI",
                "--platforms", "iOS 18.0",
                "--features", "devTooling,gitHooks,claudeMD",
            ]),
            LintFixture(label: "app, SwiftData + CloudKit + Mac Catalyst, no tabs", kind: .app, name: "LintSync", flags: [
                "--project-system", "xcodegen",
                "--platforms", "iPhone,iPad,macCatalyst",
                "--features", "swiftData,cloudKit,devTooling",
            ], runsTestsSerially: true),
            LintFixture(label: "app, LumiKit with every other feature", kind: .app, name: "LintFull", flags: [
                "--project-system", "xcodegen",
                "--platforms", "iPhone,iPad,macCatalyst",
                "--tabs", "Home:house.fill,Library:books.vertical,Settings:gear",
                "--locales", "en,zh-Hans",
                "--features", "coreData,cloudKit,cloudKitSharing,lumiKit,widget,notifications,deepLinks,spotlight,deferredLaunchWork,"
                    + "localization,combine,lottie,appIconValidation,privacyManifest,devTooling,gitHooks",
            ], runsTestsSerially: true),
            LintFixture(label: "app without LumiKit", kind: .app, name: "LintPlain", flags: [
                "--project-system", "xcodegen",
                "--platforms", "iPhone,iPad,macCatalyst",
                "--tabs", "Home:house.fill,Settings:gear",
                "--features", "darkMode,coreData,combine,devTooling",
            ], runsTestsSerially: true),
            LintFixture(label: "app, full preset", kind: .app, name: "LintPreset", flags: [
                "--project-system", "xcodegen",
                "--preset", "full",
            ], runsTestsSerially: true),
            LintFixture(label: "app, dev tooling only", kind: .app, name: "LintMini", flags: [
                "--project-system", "xcodegen",
                "--features", "devTooling",
            ]),
        ]

        /// Renders `fixture` into `root` with the real command and returns the project directory.
        private static func render(_ fixture: LintFixture, into root: String) throws -> String {
            let flags = ["--name", fixture.name] + fixture.flags + ["--no-interactive", "--no-git", "--force", "--output", root]
            switch fixture.kind {
            case .app:
                let command = try NewAppCommand.parse(flags)
                try command.run()
            case .package:
                let command = try NewPackageCommand.parse(flags)
                try command.run()
            case .cli:
                let command = try NewCLICommand.parse(flags)
                try command.run()
            }
            return (root as NSString).appendingPathComponent(fixture.name)
        }

        // MARK: - Lint gates

        @Test(.enabled(if: linters != nil, "needs swiftlint and swiftformat on PATH"), arguments: fixtures)
        func `generated project passes its own lint and format checks`(fixture: LintFixture) throws {
            let tools = try #require(linters)
            try withTempDir(prefix: "monolith-test-lint") { tempDir in
                let project = try Self.render(fixture, into: tempDir)
                #expect(FileManager.default.fileExists(atPath: "\(project)/.swiftlint.yml"))
                #expect(FileManager.default.fileExists(atPath: "\(project)/.swiftformat"))

                let lint = try ShellRunner.run(
                    executable: tools.swiftlint,
                    arguments: ["lint", "--strict", "--quiet", "--no-cache"],
                    cwd: project,
                    captureStdout: true,
                    captureStderr: true
                )
                #expect(lint.exitCode == 0, "swiftlint --strict fails on the \(fixture.label) scaffold:\n\(lint.stdout)\n\(lint.stderr)")

                let format = try ShellRunner.run(
                    executable: tools.swiftformat,
                    arguments: ["--lint", "."],
                    cwd: project,
                    captureStdout: true,
                    captureStderr: true
                )
                #expect(format.exitCode == 0, "swiftformat --lint fails on the \(fixture.label) scaffold:\n\(format.stderr)\n\(format.stdout)")
            }
        }

        // MARK: - Structure

        /// The test file's `.serialized` parent suite and the Makefile's
        /// `-parallel-testing-enabled NO` follow one rule, so an app never
        /// serializes in one place and races in the other.
        @Test(arguments: fixtures.filter { $0.kind == .app })
        func `app test serialization matches its Makefile`(fixture: LintFixture) throws {
            try withTempDir(prefix: "monolith-test-serial") { tempDir in
                let project = try Self.render(fixture, into: tempDir)
                let tests = try String(contentsOfFile: "\(project)/\(fixture.name)Tests/\(fixture.name)Tests.swift", encoding: .utf8)
                let makefile = try String(contentsOfFile: "\(project)/Makefile", encoding: .utf8)
                #expect(tests.contains("@Suite(.serialized)\nenum \(fixture.name)TestSuite {}") == fixture.runsTestsSerially)
                #expect(makefile.contains("  -parallel-testing-enabled NO \\") == fixture.runsTestsSerially)
            }
        }

        /// A package that ships an executable commits `Package.resolved`, so
        /// its `.gitignore` leaves it tracked; a library-only package ignores it.
        @Test
        func `package gitignore tracks Package_resolved only with an executable`() throws {
            let packages = Self.fixtures.filter { $0.kind == .package }
            try withTempDir(prefix: "monolith-test-resolved") { tempDir in
                for fixture in packages {
                    let project = try Self.render(fixture, into: tempDir)
                    let ignored = try String(contentsOfFile: "\(project)/.gitignore", encoding: .utf8)
                        .components(separatedBy: "\n")
                        .contains("Package.resolved")
                    let hasExecutable = fixture.flags.contains { $0.contains(":exec") }
                    #expect(ignored == !hasExecutable, "\(fixture.label): Package.resolved ignored = \(ignored)")
                }
            }
        }
    }
}
