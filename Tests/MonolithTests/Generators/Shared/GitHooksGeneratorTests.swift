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
    func `pre-commit hook runs SwiftLint with strict mode`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("swiftlint lint --strict"))
    }

    @Test
    func `pre-commit hook runs SwiftFormat in lint mode`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("swiftformat --lint"))
    }

    @Test
    func `pre-commit hook exits early when no Swift files staged`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("exit 0"))
    }

    @Test
    func `pre-commit hook degrades gracefully when tools missing`() {
        let output = GitHooksGenerator.generatePreCommitHook()
        #expect(output.contains("command -v swiftlint"))
        #expect(output.contains("command -v swiftformat"))
        #expect(output.contains("warning:"))
    }
}
