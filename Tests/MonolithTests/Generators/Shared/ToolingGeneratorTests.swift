import Foundation
import Testing
@testable import MonolithLib

@Suite("ToolingGenerator")
struct ToolingGeneratorTests {

    // MARK: - SwiftLint

    @Test("SwiftLint includes correct disabled rules")
    func swiftLintDisabledRules() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .package)
        #expect(output.contains("function_body_length"))
        #expect(output.contains("function_parameter_count"))
        #expect(output.contains("identifier_name"))
        #expect(output.contains("large_tuple"))
        #expect(output.contains("trailing_whitespace"))
    }

    @Test("SwiftLint includes correct opt-in rules")
    func swiftLintOptInRules() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .package)
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

    @Test("SwiftLint trailing comma with mandatory comma")
    func swiftLintTrailingComma() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .package)
        #expect(output.contains("trailing_comma:"))
        #expect(output.contains("mandatory_comma: true"))
    }

    @Test("SwiftLint includes Sources for package")
    func swiftLintPackageIncluded() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .package)
        #expect(output.contains("- Sources"))
    }

    @Test("SwiftLint includes app name for app")
    func swiftLintAppIncluded() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .app, appName: "MyApp")
        #expect(output.contains("- MyApp"))
    }

    @Test("SwiftLint excludes Generated when R.swift enabled")
    func swiftLintRSwiftExcluded() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .app, appName: "MyApp", hasRSwift: true)
        #expect(output.contains("MyApp/Generated"))
    }

    @Test("SwiftLint excludes fastlane when enabled")
    func swiftLintFastlaneExcluded() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .app, appName: "MyApp", hasFastlane: true)
        #expect(output.contains("- fastlane"))
    }

    @Test("SwiftLint line length is 200")
    func swiftLintLineLength() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .package)
        #expect(output.contains("line_length: 200"))
    }

    @Test("SwiftLint type body length thresholds")
    func swiftLintTypeBodyLength() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .package)
        #expect(output.contains("- 1000 # warning"))
        #expect(output.contains("- 2000 # error"))
    }

    @Test("SwiftLint cyclomatic complexity thresholds")
    func swiftLintComplexity() {
        let output = ToolingGenerator.generateSwiftLint(projectType: .package)
        #expect(output.contains("warning: 20"))
        #expect(output.contains("error: 40"))
    }

    // MARK: - SwiftFormat

    @Test("SwiftFormat includes correct options")
    func swiftFormatOptions() {
        let output = ToolingGenerator.generateSwiftFormat()
        #expect(output.contains("--indent 4"))
        #expect(output.contains("--maxwidth 200"))
        #expect(output.contains("--swiftversion 6.2"))
        #expect(output.contains("--self remove"))
        #expect(output.contains("--importgrouping testable-bottom"))
    }

    @Test("SwiftFormat includes correct enabled rules")
    func swiftFormatEnabledRules() {
        let output = ToolingGenerator.generateSwiftFormat()
        #expect(output.contains("--enable unusedPrivateDeclarations"))
        #expect(output.contains("--enable preferFinalClasses"))
        #expect(output.contains("--enable redundantAsync"))
        #expect(output.contains("--enable sortImports"))
        #expect(output.contains("--enable markTypes"))
    }

    @Test("SwiftFormat includes correct disabled rules")
    func swiftFormatDisabledRules() {
        let output = ToolingGenerator.generateSwiftFormat()
        #expect(output.contains("--disable redundantSelf"))
        #expect(output.contains("--disable unusedArguments"))
        #expect(output.contains("--disable wrapMultilineStatementBraces"))
    }

    @Test("SwiftFormat extra excludes")
    func swiftFormatExtraExcludes() {
        let output = ToolingGenerator.generateSwiftFormat(excludeExtras: ["fastlane", "Generated"])
        #expect(output.contains("--exclude .build,Build,fastlane,Generated"))
    }

    // MARK: - Makefile

    @Test("Makefile base targets for package")
    func makefileBasePackage() {
        let output = ToolingGenerator.generateMakefile(projectType: .package)
        #expect(output.contains(".PHONY:"))
        #expect(output.contains("lint:"))
        #expect(output.contains("lint-fix:"))
        #expect(output.contains("format:"))
        #expect(output.contains("check:"))
        #expect(output.contains("swift build"))
        #expect(output.contains("swift test"))
    }

    @Test("Makefile app targets include SCHEME")
    func makefileAppTargets() {
        let output = ToolingGenerator.generateMakefile(projectType: .app, appName: "TestApp")
        #expect(output.contains("SCHEME = TestApp"))
        #expect(output.contains("xcodebuild build"))
        #expect(output.contains("xcodebuild test"))
        #expect(output.contains("archive:"))
        #expect(output.contains("release: archive export upload"))
    }

    @Test("Makefile app with Fastlane adds targets")
    func makefileAppFastlane() {
        let output = ToolingGenerator.generateMakefile(projectType: .app, appName: "TestApp", hasFastlane: true)
        #expect(output.contains("fastlane-validate:"))
        #expect(output.contains("fastlane-beta:"))
        #expect(output.contains("bundle exec fastlane"))
    }

    // MARK: - Brewfile

    @Test("Brewfile base tools")
    func brewfileBase() {
        let output = ToolingGenerator.generateBrewfile()
        #expect(output.contains(#"brew "swiftlint""#))
        #expect(output.contains(#"brew "swiftformat""#))
    }

    @Test("Brewfile includes xcodegen for XcodeGen project")
    func brewfileXcodeGen() {
        let output = ToolingGenerator.generateBrewfile(projectSystem: .xcodeGen)
        #expect(output.contains(#"brew "xcodegen""#))
    }

    @Test("Brewfile excludes xcodegen for SPM project")
    func brewfileSPM() {
        let output = ToolingGenerator.generateBrewfile(projectSystem: .spm)
        #expect(!output.contains("xcodegen"))
    }

    @Test("Brewfile includes mint comment when R.swift enabled")
    func brewfileRSwift() {
        let output = ToolingGenerator.generateBrewfile(hasRSwift: true)
        #expect(output.contains("mint"))
    }
}
