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
            #expect(afterReminder.contains("STAGED=$(git diff --cached"))
        }
    }
}
