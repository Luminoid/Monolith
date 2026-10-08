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

    @Test
    func `formatStatus shows a requirement note and what uses the tool`() {
        let status = ToolChecker.ToolStatus(
            name: "xcodegen", available: true, version: "Version: 2.46.0", required: false,
            requirementNote: "required for new app", usedBy: "new app (both project systems)"
        )
        #expect(ToolChecker.formatStatus(status) == "  \(UISymbols.check) xcodegen (required for new app) (Version: 2.46.0): new app (both project systems)")
    }

    // MARK: - versionLine

    /// fastlane prints a banner and its install path, which holds a version
    /// of its own, before the version line.
    @Test
    func `versionLine skips a banner and a path`() {
        let fastlane = """
        fastlane installation at path:
        /opt/homebrew/Cellar/fastlane/2.228.0/libexec/gems/fastlane-2.228.0/bin/fastlane
        -----------------------------
        [✔] 🚀
        fastlane 2.228.0
        """
        #expect(ToolChecker.versionLine(in: fastlane) == "fastlane 2.228.0")
    }

    @Test
    func `versionLine takes the first versioned line`() {
        #expect(ToolChecker.versionLine(in: "Version: 2.46.0") == "Version: 2.46.0")
        #expect(ToolChecker.versionLine(in: "0.63.1\n") == "0.63.1")
        #expect(ToolChecker.versionLine(in: "git version 2.50.1 (Apple Git-155)") == "git version 2.50.1 (Apple Git-155)")
        #expect(ToolChecker.versionLine(in: "no version here") == nil)
    }
}
