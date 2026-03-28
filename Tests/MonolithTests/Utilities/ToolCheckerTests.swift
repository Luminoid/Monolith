import Testing
@testable import MonolithLib

struct ToolCheckerTests {
    @Test
    func `swift is always available`() {
        let status = ToolChecker.check(name: "swift", versionFlag: "--version", required: true)
        #expect(status.available)
        #expect(status.name == "swift")
        #expect(status.required)
        #expect(status.version != nil)
    }

    @Test
    func `git is available`() {
        let status = ToolChecker.check(name: "git", versionFlag: "--version")
        #expect(status.available)
        #expect(status.version != nil)
    }

    @Test
    func `nonexistent tool is not available`() {
        let status = ToolChecker.check(name: "monolith-fake-tool-xyz", required: false)
        #expect(!status.available)
        #expect(status.version == nil)
    }

    @Test
    func `whichPath finds swift`() {
        let path = ToolChecker.whichPath(for: "swift")
        #expect(path != nil)
        #expect(path?.contains("swift") == true)
    }

    @Test
    func `whichPath returns nil for nonexistent tool`() {
        let path = ToolChecker.whichPath(for: "monolith-fake-tool-xyz")
        #expect(path == nil)
    }

    @Test
    func `formatStatus shows checkmark for available tools`() {
        let status = ToolChecker.ToolStatus(name: "swift", available: true, version: "6.2", required: true)
        let output = ToolChecker.formatStatus(status)
        #expect(output.contains("\u{2713}"))
        #expect(output.contains("swift"))
        #expect(output.contains("6.2"))
        #expect(output.contains("required"))
    }

    @Test
    func `formatStatus shows X for missing tools`() {
        let status = ToolChecker.ToolStatus(name: "xcodegen", available: false, version: nil, required: false)
        let output = ToolChecker.formatStatus(status)
        #expect(output.contains("\u{2717}"))
        #expect(output.contains("xcodegen"))
    }
}
