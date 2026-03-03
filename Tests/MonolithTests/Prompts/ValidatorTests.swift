import Foundation
import Testing
@testable import MonolithLib

@Suite("Validators")
struct ValidatorTests {
    // MARK: - Project Name

    @Test("valid project names")
    func validProjectNames() {
        #expect(Validators.validateProjectName("MyApp"))
        #expect(Validators.validateProjectName("my-app"))
        #expect(Validators.validateProjectName("my_app"))
        #expect(Validators.validateProjectName("App123"))
        #expect(Validators.validateProjectName("A"))
    }

    @Test("invalid project names - empty")
    func emptyName() {
        #expect(!Validators.validateProjectName(""))
    }

    @Test("invalid project names - starts with number")
    func startsWithNumber() {
        #expect(!Validators.validateProjectName("123App"))
    }

    @Test("invalid project names - starts with hyphen")
    func startsWithHyphen() {
        #expect(!Validators.validateProjectName("-app"))
    }

    @Test("invalid project names - special characters")
    func specialCharacters() {
        #expect(!Validators.validateProjectName("My App"))
        #expect(!Validators.validateProjectName("My.App"))
        #expect(!Validators.validateProjectName("My@App"))
    }

    @Test("invalid project names - too long")
    func tooLongName() {
        let longName = String(repeating: "a", count: 51)
        #expect(!Validators.validateProjectName(longName))
    }

    @Test("project name at max length")
    func maxLengthName() {
        let maxName = "A" + String(repeating: "a", count: 49)
        #expect(Validators.validateProjectName(maxName))
    }

    // MARK: - Sanitize Project Name

    @Test("sanitize project name strips spaces")
    func sanitizeSpaces() {
        #expect(Validators.sanitizeProjectName("My App") == "MyApp")
    }

    @Test("sanitize project name strips special chars")
    func sanitizeSpecialChars() {
        #expect(Validators.sanitizeProjectName("My.App!") == "MyApp")
    }

    @Test("sanitize project name strips leading digits")
    func sanitizeLeadingDigits() {
        #expect(Validators.sanitizeProjectName("123App") == "App")
    }

    @Test("sanitize project name trims to 50 chars")
    func sanitizeTruncate() {
        let longName = "A" + String(repeating: "b", count: 60)
        let result = Validators.sanitizeProjectName(longName)
        #expect(result.count == 50)
    }

    // MARK: - Bundle ID

    @Test("valid bundle IDs")
    func validBundleIDs() {
        #expect(Validators.validateBundleID("com.example.app"))
        #expect(Validators.validateBundleID("com.my-company.my-app"))
        #expect(Validators.validateBundleID("io.github.user.project"))
        #expect(Validators.validateBundleID("com.example"))
    }

    @Test("invalid bundle IDs - single segment")
    func singleSegment() {
        #expect(!Validators.validateBundleID("myapp"))
    }

    @Test("invalid bundle IDs - empty segment")
    func emptySegment() {
        #expect(!Validators.validateBundleID("com..app"))
        #expect(!Validators.validateBundleID(".com.app"))
    }

    @Test("invalid bundle IDs - segment starts with number")
    func segmentStartsWithNumber() {
        #expect(!Validators.validateBundleID("com.123.app"))
    }

    @Test("invalid bundle IDs - special characters")
    func bundleIDSpecialChars() {
        #expect(!Validators.validateBundleID("com.example.my app"))
        #expect(!Validators.validateBundleID("com.example.my@app"))
    }

    @Test("invalid bundle IDs - empty")
    func emptyBundleID() {
        #expect(!Validators.validateBundleID(""))
    }

    // MARK: - Hex Color

    @Test("valid hex colors")
    func validHexColors() {
        #expect(Validators.validateHexColor("#4CAF7D"))
        #expect(Validators.validateHexColor("#000000"))
        #expect(Validators.validateHexColor("#FFFFFF"))
        #expect(Validators.validateHexColor("#ffffff"))
        #expect(Validators.validateHexColor("#4caf7d"))
        #expect(Validators.validateHexColor("#AbCdEf"))
    }

    @Test("invalid hex colors - missing hash")
    func missingHash() {
        #expect(!Validators.validateHexColor("4CAF7D"))
    }

    @Test("invalid hex colors - wrong length")
    func wrongLength() {
        #expect(!Validators.validateHexColor("#4CA"))
        #expect(!Validators.validateHexColor("#4CAF7D00"))
    }

    @Test("invalid hex colors - non-hex characters")
    func nonHexChars() {
        #expect(!Validators.validateHexColor("#GGGGGG"))
        #expect(!Validators.validateHexColor("#4CAF7Z"))
    }

    @Test("invalid hex colors - empty")
    func emptyHex() {
        #expect(!Validators.validateHexColor(""))
        #expect(!Validators.validateHexColor("#"))
    }

    // MARK: - Deployment Target

    @Test("valid deployment targets")
    func validDeploymentTargets() {
        #expect(Validators.validateDeploymentTarget("18.0"))
        #expect(Validators.validateDeploymentTarget("18.4"))
        #expect(Validators.validateDeploymentTarget("19.0"))
    }

    @Test("invalid deployment targets - below 18")
    func belowMinimum() {
        #expect(!Validators.validateDeploymentTarget("17.0"))
        #expect(!Validators.validateDeploymentTarget("16.4"))
    }

    @Test("invalid deployment targets - wrong format")
    func wrongFormat() {
        #expect(!Validators.validateDeploymentTarget("18"))
        #expect(!Validators.validateDeploymentTarget("18.0.1"))
        #expect(!Validators.validateDeploymentTarget("abc"))
    }

    // MARK: - Default Bundle ID

    @Test("default bundle ID from project name")
    func defaultBundleID() {
        #expect(Validators.defaultBundleID(for: "MyApp") == "com.example.myapp")
        #expect(Validators.defaultBundleID(for: "my_app") == "com.example.my-app")
    }

    // MARK: - Tab Parsing

    @Test("parse valid tabs")
    func parseTabs() {
        let tabs = PromptEngine.parseTabs("Home:house, Settings:gearshape")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
        #expect(tabs[1].name == "Settings")
        #expect(tabs[1].icon == "gearshape")
    }

    @Test("parse single tab")
    func parseSingleTab() {
        let tabs = PromptEngine.parseTabs("Home:house")
        #expect(tabs.count == 1)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
    }

    @Test("parse tabs with extra whitespace")
    func parseTabsWhitespace() {
        let tabs = PromptEngine.parseTabs("  Home : house ,  Settings : gearshape  ")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
    }

    @Test("parse empty tabs input")
    func parseEmptyTabs() {
        let tabs = PromptEngine.parseTabs("")
        #expect(tabs.isEmpty)
    }

    @Test("parse tabs with invalid entries skipped")
    func parseTabsInvalid() {
        let tabs = PromptEngine.parseTabs("Home:house, invalid, Settings:gearshape")
        #expect(tabs.count == 2)
    }
}
