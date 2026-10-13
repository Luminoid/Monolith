import Foundation
import Testing
@testable import MonolithLib

struct SwiftLintGeneratorTests {
    /// The entries of a top-level YAML list (`included:` / `excluded:`).
    private func list(_ key: String, in output: String) -> [String] {
        let lines = output.components(separatedBy: "\n")
        guard let start = lines.firstIndex(of: "\(key):") else { return [] }
        return lines[(start + 1)...]
            .prefix { $0.hasPrefix("  - ") }
            .map { String($0.dropFirst(4)) }
    }

    @Test
    func `includes correct disabled rules`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("function_body_length"))
        #expect(output.contains("function_parameter_count"))
        #expect(output.contains("identifier_name"))
        #expect(output.contains("large_tuple"))
        #expect(output.contains("trailing_whitespace"))
    }

    @Test
    func `includes correct opt-in rules`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("contains_over_filter_count"))
        #expect(output.contains("empty_count"))
        #expect(output.contains("first_where"))
        #expect(output.contains("force_unwrapping"))
        #expect(output.contains("for_where"))
        #expect(output.contains("implicit_return"))
        #expect(output.contains("prefer_self_in_static_references"))
        #expect(output.contains("private_over_fileprivate"))
        #expect(output.contains("sorted_first_last"))
    }

    @Test
    func `trailing comma with mandatory comma`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("trailing_comma:"))
        #expect(output.contains("mandatory_comma: true"))
    }

    @Test
    func `includes Sources and Tests for package`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("- Sources"))
        #expect(output.contains("- Tests"))
    }

    @Test
    func `cli lints Sources and Tests, like the commit hook`() {
        let output = SwiftLintGenerator.generate(projectType: .cli)
        #expect(list("included", in: output) == ["Sources", "Tests"])
    }

    @Test
    func `app lints its sources and tests`() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp")
        #expect(list("included", in: output) == ["MyApp", "MyAppTests"])
    }

    @Test
    func `app with a widget lints the widget too`() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp", hasWidget: true)
        #expect(list("included", in: output) == ["MyApp", "MyAppTests", "MyAppWidget"])
    }

    @Test
    func `excludes Generated when R.swift enabled`() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp", hasRSwift: true)
        #expect(list("excluded", in: output) == [".build", "MyApp/Generated"])
    }

    @Test
    func `excludes fastlane when enabled`() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp", hasFastlane: true)
        #expect(list("excluded", in: output) == [".build", "fastlane"])
    }

    @Test
    func `tool excludes are shared with SwiftFormat`() {
        #expect(SwiftLintGenerator.toolExcludes(appName: "MyApp", hasRSwift: true, hasFastlane: true) == ["MyApp/Generated", "fastlane"])
        #expect(SwiftLintGenerator.toolExcludes(appName: "MyApp", hasRSwift: false, hasFastlane: false).isEmpty)
    }

    @Test
    func `update check is off`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("\ncheck_for_updates: false\n"))
        #expect(!output.contains("check_for_updates: true"))
    }

    @Test
    func `line length is 200`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("line_length: 200"))
    }

    @Test
    func `type body length thresholds`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("- 1000 # warning"))
        #expect(output.contains("- 2000 # error"))
    }

    @Test
    func `cyclomatic complexity thresholds`() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("warning: 20"))
        #expect(output.contains("error: 40"))
    }
}
