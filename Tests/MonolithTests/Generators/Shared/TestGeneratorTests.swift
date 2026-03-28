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
    func `both generators use Swift Testing framework`() {
        let packageTest = TestGenerator.generate(suiteName: "Test", targetName: "Test")
        #expect(packageTest.contains("import Testing"))
        #expect(packageTest.contains("@Test"))
        #expect(packageTest.contains("#expect"))

        let appTest = TestGenerator.generateAppTest(suiteName: "Test")
        #expect(appTest.contains("import Testing"))
        #expect(appTest.contains("@Test"))
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
