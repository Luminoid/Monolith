import Foundation
import Testing
@testable import MonolithLib

@Suite("SwiftLintGenerator")
struct SwiftLintGeneratorTests {
    @Test("includes correct disabled rules")
    func disabledRules() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("function_body_length"))
        #expect(output.contains("function_parameter_count"))
        #expect(output.contains("identifier_name"))
        #expect(output.contains("large_tuple"))
        #expect(output.contains("trailing_whitespace"))
    }

    @Test("includes correct opt-in rules")
    func optInRules() {
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

    @Test("trailing comma with mandatory comma")
    func trailingComma() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("trailing_comma:"))
        #expect(output.contains("mandatory_comma: true"))
    }

    @Test("includes Sources and Tests for package")
    func packageIncluded() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("- Sources"))
        #expect(output.contains("- Tests"))
    }

    @Test("cli includes only Sources")
    func cliIncluded() {
        let output = SwiftLintGenerator.generate(projectType: .cli)
        #expect(output.contains("- Sources"))
        #expect(!output.contains("- Tests"))
    }

    @Test("includes app name for app")
    func appIncluded() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp")
        #expect(output.contains("- MyApp"))
    }

    @Test("excludes Generated when R.swift enabled")
    func rSwiftExcluded() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp", hasRSwift: true)
        #expect(output.contains("MyApp/Generated"))
    }

    @Test("excludes fastlane when enabled")
    func fastlaneExcluded() {
        let output = SwiftLintGenerator.generate(projectType: .app, appName: "MyApp", hasFastlane: true)
        #expect(output.contains("- fastlane"))
    }

    @Test("line length is 200")
    func lineLength() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("line_length: 200"))
    }

    @Test("type body length thresholds")
    func typeBodyLength() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("- 1000 # warning"))
        #expect(output.contains("- 2000 # error"))
    }

    @Test("cyclomatic complexity thresholds")
    func complexity() {
        let output = SwiftLintGenerator.generate(projectType: .package)
        #expect(output.contains("warning: 20"))
        #expect(output.contains("error: 40"))
    }
}
