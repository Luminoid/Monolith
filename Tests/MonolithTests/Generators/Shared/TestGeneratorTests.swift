import Foundation
import Testing
@testable import MonolithLib

struct TestGeneratorTests {
    @Test
    func `generates test with @testable import`() {
        let output = TestGenerator.generate(suiteName: "MyLib", targetName: "MyLib")
        #expect(output.contains("@testable import MyLib"))
        #expect(output.contains("@Suite(\"MyLib\")"))
        #expect(output.contains("struct MyLibTests"))
    }

    @Test
    func `generates app test without @testable import`() {
        let output = TestGenerator.generateAppTest(suiteName: "MyApp")
        #expect(!output.contains("@testable"))
        #expect(output.contains("@Suite(\"MyApp\")"))
        #expect(output.contains("struct MyAppTests"))
    }

    @Test
    func `both generators import Swift Testing framework`() {
        // Both stubs import Testing so adopters can add @Test methods inside the
        // empty @Suite without an additional import. The stubs themselves carry
        // no actual @Test/#expect calls — those would inflate the test count
        // with content-free assertions (`#expect(Bool(true))` always passes by
        // construction, contributes no signal). See TestGenerator docstring.
        let packageTest = TestGenerator.generate(suiteName: "Test", targetName: "Test")
        #expect(packageTest.contains("import Testing"))
        #expect(packageTest.contains("@Suite(\"Test\")"))

        let appTest = TestGenerator.generateAppTest(suiteName: "Test")
        #expect(appTest.contains("import Testing"))
        #expect(appTest.contains("@Suite(\"Test\")"))
    }

    @Test
    func `package generator emits empty Suite with no placeholder test`() {
        let output = TestGenerator.generate(suiteName: "MyLib", targetName: "MyLib")
        // Stub is intentionally content-free: no @Test, no #expect.
        #expect(!output.contains("@Test"))
        #expect(!output.contains("#expect"))
        #expect(!output.contains("placeholder"))
        #expect(!output.contains("Bool(true)"))
        // No reminder-comment line — SwiftLint's `todo` rule is on by
        // default in the generated .swiftlint.yml, so any such marker would
        // fail `make check` on the first run of a freshly scaffolded
        // package. The empty struct body is itself the prompt to write tests.
        let marker = "// " + "TODO"
        #expect(!output.contains(marker))
        // Empty struct body — confirm structurally, not just by substring.
        #expect(output.contains("struct MyLibTests {}"))
    }

    @Test
    func `app generator emits empty Suite with no appLaunches test`() {
        let output = TestGenerator.generateAppTest(suiteName: "MyApp")
        #expect(!output.contains("@Test"))
        #expect(!output.contains("appLaunches"))
        #expect(!output.contains("#expect"))
        let marker = "// " + "TODO"
        #expect(!output.contains(marker))
        #expect(output.contains("struct MyAppTests {}"))
    }

    @Test
    func `both generators end with trailing newline`() {
        let packageTest = TestGenerator.generate(suiteName: "Test", targetName: "Test")
        #expect(packageTest.hasSuffix("\n"))

        let appTest = TestGenerator.generateAppTest(suiteName: "Test")
        #expect(appTest.hasSuffix("\n"))
    }

    @Test
    func `both generators import Foundation`() {
        let packageTest = TestGenerator.generate(suiteName: "Test", targetName: "Test")
        #expect(packageTest.contains("import Foundation"))

        let appTest = TestGenerator.generateAppTest(suiteName: "Test")
        #expect(appTest.contains("import Foundation"))
    }

    // MARK: - Persistence Demo

    @Test
    func `withPersistenceDemo emits a SampleItem round-trip test`() {
        // The demo test exercises TestContext + TestDataFactory so the
        // scaffold's test count starts at 1 (a green signal) and the helpers
        // are referenced rather than dead code. Adopters delete the demo when
        // they write their first real test.
        let output = TestGenerator.generateAppTest(suiteName: "MyApp", withPersistenceDemo: true)
        #expect(output.contains("@Test"))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("@testable import MyApp"))
        #expect(output.contains("TestContext.makeContainer()"))
        #expect(output.contains("TestDataFactory.makeSampleItem"))
        #expect(output.contains("#expect"))
        #expect(output.contains("@MainActor"))
    }

    @Test
    func `withPersistenceDemo defaults to false (back-compat)`() {
        // No persistence demo by default — keeps the old behavior for apps
        // without SwiftData/CoreData (empty suite, no SwiftData import).
        let output = TestGenerator.generateAppTest(suiteName: "MyApp")
        #expect(!output.contains("import SwiftData"))
        #expect(!output.contains("@Test"))
        #expect(output.contains("struct MyAppTests {}"))
    }
}
