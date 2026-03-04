import Testing
@testable import MonolithLib

@Suite("ToolChecker")
struct ToolCheckerTests {
    @Test("swift is always available")
    func swiftAvailable() {
        let status = ToolChecker.check(name: "swift", versionFlag: "--version", required: true)
        #expect(status.available)
        #expect(status.name == "swift")
        #expect(status.required)
        #expect(status.version != nil)
    }

    @Test("git is available")
    func gitAvailable() {
        let status = ToolChecker.check(name: "git", versionFlag: "--version")
        #expect(status.available)
        #expect(status.version != nil)
    }

    @Test("nonexistent tool is not available")
    func nonexistentTool() {
        let status = ToolChecker.check(name: "monolith-fake-tool-xyz", required: false)
        #expect(!status.available)
        #expect(status.version == nil)
    }

    @Test("whichPath finds swift")
    func whichPathFindsSwift() {
        let path = ToolChecker.whichPath(for: "swift")
        #expect(path != nil)
        #expect(path?.contains("swift") == true)
    }

    @Test("whichPath returns nil for nonexistent tool")
    func whichPathNonexistent() {
        let path = ToolChecker.whichPath(for: "monolith-fake-tool-xyz")
        #expect(path == nil)
    }

    @Test("formatStatus shows checkmark for available tools")
    func formatAvailable() {
        let status = ToolChecker.ToolStatus(name: "swift", available: true, version: "6.2", required: true)
        let output = ToolChecker.formatStatus(status)
        #expect(output.contains("\u{2713}"))
        #expect(output.contains("swift"))
        #expect(output.contains("6.2"))
        #expect(output.contains("required"))
    }

    @Test("formatStatus shows X for missing tools")
    func formatMissing() {
        let status = ToolChecker.ToolStatus(name: "xcodegen", available: false, version: nil, required: false)
        let output = ToolChecker.formatStatus(status)
        #expect(output.contains("\u{2717}"))
        #expect(output.contains("xcodegen"))
    }
}
