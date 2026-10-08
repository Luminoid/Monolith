import Foundation
import Testing
@testable import MonolithLib

struct SwiftFormatGeneratorTests {
    /// The config's active option and rule lines, comments and blanks dropped.
    private func directives(_ output: String) -> [String] {
        output.components(separatedBy: "\n")
            .map { line in
                let code = line.components(separatedBy: "#").first ?? line
                return code.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    @Test
    func `includes correct options`() {
        let lines = directives(SwiftFormatGenerator.generate())
        #expect(lines.contains("--indent 4"))
        #expect(lines.contains("--max-width 200"))
        #expect(lines.contains("--swift-version \(ToolVersion.swift)"))
        #expect(lines.contains("--self remove"))
        #expect(lines.contains("--import-grouping testable-bottom"))
        #expect(lines.contains("--trailing-commas collections-only"))
    }

    @Test
    func `options use kebab-case names`() {
        // SwiftFormat 0.57 renamed its options; the run-together spellings are legacy aliases.
        let legacy = [
            "--maxwidth", "--swiftversion", "--importgrouping", "--binarygrouping", "--decimalgrouping",
            "--elseposition", "--voidtype", "--exponentcase", "--hexliteralcase", "--indentcase",
            "--operatorfunc", "--patternlet", "--trimwhitespace", "--wraparguments", "--wrapcollections",
            "--wrapconditions", "--minversion",
        ]
        let lines = directives(SwiftFormatGenerator.generate())
        for option in legacy {
            #expect(!lines.contains { $0.hasPrefix(option + " ") }, "\(option) is a legacy spelling")
        }
    }

    @Test
    func `declares the Brewfile floor as the minimum version`() {
        let lines = directives(SwiftFormatGenerator.generate())
        #expect(lines.contains("--min-version \(ToolVersion.swiftformatFloor)"))
    }

    @Test
    func `enables only opt-in rules`() {
        let lines = directives(SwiftFormatGenerator.generate())
        let enabled = Set(lines.filter { $0.hasPrefix("--enable ") }.map { String($0.dropFirst("--enable ".count)) })
        #expect(enabled == ["unusedPrivateDeclarations", "emptyExtensions", "isEmpty", "preferFinalClasses"])
    }

    @Test
    func `disables only default rules`() {
        let lines = directives(SwiftFormatGenerator.generate())
        let disabled = Set(lines.filter { $0.hasPrefix("--disable ") }.map { String($0.dropFirst("--disable ".count)) })
        #expect(disabled == [
            "consecutiveSpaces", "redundantSelf", "unusedArguments", "wrapMultilineStatementBraces",
            "wrapPropertyBodies", "wrapIfStatementBodies", "wrapIfExpressionBodies",
        ])
    }

    @Test
    func `default excludes cover both build directory spellings`() {
        let output = SwiftFormatGenerator.generate()
        #expect(output.contains("--exclude .build,Build,build\n"))
    }

    @Test
    func `extra excludes`() {
        let output = SwiftFormatGenerator.generate(excludeExtras: ["fastlane", "Generated"])
        #expect(output.contains("--exclude .build,Build,build,fastlane,Generated"))
    }

    /// Runs the installed SwiftFormat against the generated config: an unknown
    /// option or rule, or an `--enable` of a default rule, prints a warning.
    @Test
    func `installed SwiftFormat accepts the config without warnings`() throws {
        guard let swiftformat = ShellRunner.runCapturingStdout(executable: "/usr/bin/which", arguments: ["swiftformat"]) else { return }
        let directory = NSTemporaryDirectory() + "monolith-swiftformat-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: directory) }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try SwiftFormatGenerator.generate().write(toFile: directory + "/.swiftformat", atomically: true, encoding: .utf8)
        try "let value = 1\n".write(toFile: directory + "/Sample.swift", atomically: true, encoding: .utf8)

        let output = try ShellRunner.run(
            executable: swiftformat,
            arguments: ["--lint", "Sample.swift"],
            cwd: directory,
            captureStdout: true,
            captureStderr: true
        )

        #expect(output.exitCode == 0, "swiftformat failed: \(output.stderr)")
        #expect(!output.stderr.lowercased().contains("warning"), "\(output.stderr)")
        #expect(!output.stderr.lowercased().contains("error"), "\(output.stderr)")
    }
}
