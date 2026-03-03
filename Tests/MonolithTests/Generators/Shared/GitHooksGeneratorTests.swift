import Foundation
import Testing
@testable import MonolithLib

@Suite("GitHooksGenerator")
struct GitHooksGeneratorTests {
    @Test("pre-commit hook has bash shebang")
    func shebang() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.hasPrefix("#!/bin/bash"))
    }

    @Test("pre-commit hook checks staged Swift files only")
    func stagedFiles() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("git diff --cached --name-only"))
        #expect(output.contains("'*.swift'"))
    }

    @Test("pre-commit hook runs SwiftLint with strict mode")
    func swiftLint() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("swiftlint lint --strict"))
    }

    @Test("pre-commit hook runs SwiftFormat in lint mode")
    func swiftFormat() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("swiftformat --lint"))
    }

    @Test("pre-commit hook exits early when no Swift files staged")
    func earlyExit() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("exit 0"))
    }

    @Test("pre-commit hook degrades gracefully when tools missing")
    func gracefulDegradation() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("command -v swiftlint"))
        #expect(output.contains("command -v swiftformat"))
        #expect(output.contains("warning:"))
    }
}
