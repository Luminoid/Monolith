import Foundation
import Testing
@testable import MonolithLib

@Suite("TestGenerator")
struct TestGeneratorTests {
    @Test("generates test with @testable import")
    func verifyTestableImport() {
        let output = TestGenerator.generate(suiteName: "MyLib", targetName: "MyLib")
        #expect(output.contains("@testable import MyLib"))
        #expect(output.contains("@Suite(\"MyLib\")"))
        #expect(output.contains("struct MyLibTests"))
    }

    @Test("generates app test without @testable import")
    func appTestNoTestable() {
        let output = TestGenerator.generateAppTest(suiteName: "MyApp")
        #expect(!output.contains("@testable"))
        #expect(output.contains("@Suite(\"MyApp\")"))
        #expect(output.contains("struct MyAppTests"))
    }

    @Test("both generators use Swift Testing framework")
    func usesSwiftTesting() {
        let packageTest = TestGenerator.generate(suiteName: "Test", targetName: "Test")
        #expect(packageTest.contains("import Testing"))
        #expect(packageTest.contains("@Test"))
        #expect(packageTest.contains("#expect"))

        let appTest = TestGenerator.generateAppTest(suiteName: "Test")
        #expect(appTest.contains("import Testing"))
        #expect(appTest.contains("@Test"))
    }

    @Test("both generators import Foundation")
    func importsFoundation() {
        let packageTest = TestGenerator.generate(suiteName: "Test", targetName: "Test")
        #expect(packageTest.contains("import Foundation"))

        let appTest = TestGenerator.generateAppTest(suiteName: "Test")
        #expect(appTest.contains("import Foundation"))
    }
}
