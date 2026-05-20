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
    func `package generator emits empty Suite with reminder, no placeholder test`() {
        let output = TestGenerator.generate(suiteName: "MyLib", targetName: "MyLib")
        // Stub is intentionally content-free: no @Test, no #expect.
        #expect(!output.contains("@Test"))
        #expect(!output.contains("#expect"))
        #expect(!output.contains("placeholder"))
        #expect(!output.contains("Bool(true)"))
        // Reminder marker present so adopters get a visible nudge.
        #expect(output.contains("TODO"))
        // Empty struct body — confirm structurally, not just by substring.
        #expect(output.contains("struct MyLibTests {}"))
    }

    @Test
    func `app generator emits empty Suite with reminder, no appLaunches test`() {
        let output = TestGenerator.generateAppTest(suiteName: "MyApp")
        #expect(!output.contains("@Test"))
        #expect(!output.contains("appLaunches"))
        #expect(!output.contains("#expect"))
        #expect(output.contains("TODO"))
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
}
