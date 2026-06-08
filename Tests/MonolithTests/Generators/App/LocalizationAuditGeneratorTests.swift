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
    func `script derives locales from the catalog at runtime`() {
        // The previous hardcoded `LOCALES = ("en", "es", "zh-Hans")` constant
        // mismatched a freshly-scaffolded en-only catalog and made `make
        // check` fail out-of-the-box. The replacement reads every key's
        // `localizations` keys and unions them.
        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        #expect(!script.contains("LOCALES = ("), "hardcoded LOCALES constant should be gone")
        #expect(script.contains("def derive_locales(strings: dict)"))
        #expect(script.contains("locales = derive_locales(strings)"))
    }

    @Test
    func `script tolerates an empty catalog without crashing`() {
        let script = LocalizationAuditGenerator.generate(appName: "MyApp")
        #expect(script.contains("if not locales:"))
        #expect(script.contains("no localizations declared"))
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

    /// Drive the generated script against a synthetic en-only catalog (matches
    /// what `LocalizationGenerator.generateStringCatalog` actually emits on a
    /// fresh scaffold). The audit should exit 0 — the regression that
    /// motivated the locale-derivation fix was the hardcoded LOCALES tuple
    /// flagging missing es / zh-Hans translations on day one.
    @Test
    func `en-only catalog audits clean (regression: hardcoded LOCALES list)`() throws {
        guard let python = ShellRunner.runCapturingStdout(
            executable: "/usr/bin/which",
            arguments: ["python3"]
        ) else { return }
        let (scriptPath, _, cleanup) = try writeFixture(
            appName: "MyApp",
            catalog: """
            {
                "sourceLanguage": "en",
                "version": "1.0",
                "strings": {
                    "app.title": {
                        "localizations": {
                            "en": { "stringUnit": { "state": "translated", "value": "MyApp" } }
                        }
                    },
                    "common.ok": {
                        "localizations": {
                            "en": { "stringUnit": { "state": "translated", "value": "OK" } }
                        }
                    }
                }
            }
            """
        )
        defer { cleanup() }

        let output = try ShellRunner.run(executable: python, arguments: [scriptPath], captureStdout: true, captureStderr: true)
        #expect(output.exitCode == 0, "audit failed: \(output.stderr)\n\(output.stdout)")
        #expect(output.stdout.contains("en"), "report should name the discovered locale")
    }

    /// Multi-locale catalog with a hole (one key has en+es, the other only
    /// en) — the derived locale set includes es, so the en-only key flags as
    /// missing.
    @Test
    func `missing-translation flag fires when one key skips a derived locale`() throws {
        guard let python = ShellRunner.runCapturingStdout(
            executable: "/usr/bin/which",
            arguments: ["python3"]
        ) else { return }
        let (scriptPath, _, cleanup) = try writeFixture(
            appName: "MyApp",
            catalog: """
            {
                "sourceLanguage": "en",
                "version": "1.0",
                "strings": {
                    "app.title": {
                        "localizations": {
                            "en": { "stringUnit": { "state": "translated", "value": "MyApp" } },
                            "es": { "stringUnit": { "state": "translated", "value": "MyApp" } }
                        }
                    },
                    "common.ok": {
                        "localizations": {
                            "en": { "stringUnit": { "state": "translated", "value": "OK" } }
                        }
                    }
                }
            }
            """
        )
        defer { cleanup() }

        let output = try ShellRunner.run(executable: python, arguments: [scriptPath], captureStdout: true, captureStderr: true)
        #expect(output.exitCode == 1, "expected non-zero exit for missing translation")
        #expect(output.stdout.contains("common.ok: missing es"), "should flag the gap: \(output.stdout)")
    }

    /// A fresh multi-locale scaffold is born with every non-source locale at
    /// state=new. That must be a non-fatal warning (exit 0), not a build
    /// failure — otherwise `make check` fails on a just-generated project.
    @Test
    func `untranslated entries are non-fatal (regression: make check on fresh scaffold)`() throws {
        guard let python = ShellRunner.runCapturingStdout(
            executable: "/usr/bin/which",
            arguments: ["python3"]
        ) else { return }
        let (scriptPath, _, cleanup) = try writeFixture(
            appName: "MyApp",
            catalog: """
            {
                "sourceLanguage": "en",
                "version": "1.0",
                "strings": {
                    "app.title": {
                        "localizations": {
                            "en": { "stringUnit": { "state": "translated", "value": "MyApp" } },
                            "zh-Hans": { "stringUnit": { "state": "new", "value": "MyApp" } }
                        }
                    }
                }
            }
            """
        )
        defer { cleanup() }

        let output = try ShellRunner.run(executable: python, arguments: [scriptPath], captureStdout: true, captureStderr: true)
        #expect(output.exitCode == 0, "untranslated must be non-fatal: \(output.stdout)")
        #expect(output.stdout.contains("not yet translated"), "should report the pending translation: \(output.stdout)")
    }

    /// Placeholder arity mismatches crash Foundation at runtime, so they stay
    /// fatal even though untranslated entries don't.
    @Test
    func `placeholder mismatch stays fatal`() throws {
        guard let python = ShellRunner.runCapturingStdout(
            executable: "/usr/bin/which",
            arguments: ["python3"]
        ) else { return }
        let (scriptPath, _, cleanup) = try writeFixture(
            appName: "MyApp",
            catalog: """
            {
                "sourceLanguage": "en",
                "version": "1.0",
                "strings": {
                    "count": {
                        "localizations": {
                            "en": { "stringUnit": { "state": "translated", "value": "%lld items" } },
                            "es": { "stringUnit": { "state": "translated", "value": "elementos" } }
                        }
                    }
                }
            }
            """
        )
        defer { cleanup() }

        let output = try ShellRunner.run(executable: python, arguments: [scriptPath], captureStdout: true, captureStderr: true)
        #expect(output.exitCode == 1, "placeholder mismatch must stay fatal: \(output.stdout)")
        #expect(output.stdout.contains("placeholder mismatch"), "should name the failure: \(output.stdout)")
    }

    // MARK: - Fixture helpers

    /// Writes the generated audit script + a synthetic xcstrings catalog to a
    /// scratch directory shaped like a real Monolith app (script lives at
    /// `Scripts/localization/audit_strings.py`, catalog at
    /// `<AppName>/Resources/Localizable.xcstrings`). The script uses
    /// `parents[2]` to find the catalog, so the directory layout matters.
    private func writeFixture(appName: String, catalog: String) throws -> (scriptPath: String, root: String, cleanup: () -> Void) {
        let root = NSTemporaryDirectory() + "audit-fixture-\(UUID().uuidString)"
        let scriptDir = root + "/Scripts/localization"
        let resourceDir = root + "/\(appName)/Resources"
        try FileManager.default.createDirectory(atPath: scriptDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: resourceDir, withIntermediateDirectories: true)

        let scriptPath = scriptDir + "/audit_strings.py"
        let script = LocalizationAuditGenerator.generate(appName: appName)
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try catalog.write(toFile: resourceDir + "/Localizable.xcstrings", atomically: true, encoding: .utf8)
        return (scriptPath, root, { try? FileManager.default.removeItem(atPath: root) })
    }
}
