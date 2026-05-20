import Foundation
import Testing
@testable import MonolithLib

struct LocalizationAuditGeneratorTests {
    @Test
    func `script has shebang and Python entrypoint`() {
        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        #expect(script.hasPrefix("#!/usr/bin/env python3"))
        #expect(script.contains("if __name__ == \"__main__\":"))
        #expect(script.contains("sys.exit(main())"))
    }

    @Test
    func `script uses default locale list when not overridden`() {
        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        #expect(script.contains("LOCALES = (\"en\", \"es\", \"zh-Hans\")"))
    }

    @Test
    func `script accepts custom locale list`() {
        let script = LocalizationAuditGenerator.generate(appName: "MyApp", locales: ["en", "fr", "ja"])
        #expect(script.contains("LOCALES = (\"en\", \"fr\", \"ja\")"))
    }

    @Test
    func `script embeds the app name in the catalog path`() {
        let script = LocalizationAuditGenerator.generate(appName: "Petfolio")
        #expect(script.contains("/ \"Petfolio\""))
        #expect(script.contains("\"Localizable.xcstrings\""))
    }

    @Test
    func `script checks for Swift interpolation keys`() {
        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        // The regex literal must escape the backslash. Confirm the raw bytes
        // contain `\\(` (which Python sees as `\\(` and re module interprets
        // as the literal `\(` two-char sequence).
        #expect(script.contains("SWIFT_INTERPOLATION_RE = re.compile(r\"\\\\\\(\")"))
        // The diagnostic message should call out the format-specifier fix.
        #expect(script.contains("%@") || script.contains("%lld"))
    }

    @Test
    func `script reports missing locales and placeholder mismatches`() {
        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        #expect(script.contains("missing"))
        #expect(script.contains("placeholder mismatch"))
        #expect(script.contains("state="))
    }

    @Test
    func `script exits non-zero when the catalog is absent`() {
        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        #expect(script.contains("if not XCSTRINGS.exists():"))
        #expect(script.contains("return 2"))
    }

    /// Round-trip the generated script through `python3 -c "compile(...)"`
    /// when Python is available. Catches syntax errors that string-contains
    /// checks can't see — escape-sequence regressions in particular.
    @Test
    func `generated script is syntactically valid Python`() throws {
        // Skip when python3 isn't on the PATH (some CI runners).
        guard let python = ShellRunner.runCapturingStdout(
            executable: "/usr/bin/which",
            arguments: ["python3"]
        ) else { return }

        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        let tempPath = NSTemporaryDirectory() + "audit-\(UUID().uuidString).py"
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        try script.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let output = try ShellRunner.run(
            executable: python,
            arguments: ["-c", "import ast; ast.parse(open('\(tempPath)').read())"],
            captureStderr: true
        )
        #expect(output.exitCode == 0, "python3 ast.parse failed: \(output.stderr)")
    }
}
