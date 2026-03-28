import Foundation
import Testing
@testable import MonolithLib

struct SwiftLintGeneratorTests {
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
    func `cli includes only Sources`() {
        let output = SwiftLintGenerator.generate(projectType: .cli)
        #expect(output.contains("- Sources"))
        #expect(!output.contains("- Tests"))
    }

    @Test
    func `includes app name for app`() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp")
        #expect(output.contains("- MyApp"))
    }

    @Test
    func `excludes Generated when R.swift enabled`() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp", hasRSwift: true)
        #expect(output.contains("MyApp/Generated"))
    }

    @Test
    func `excludes fastlane when enabled`() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp", hasFastlane: true)
        #expect(output.contains("- fastlane"))
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
