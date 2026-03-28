import Foundation
import Testing
@testable import MonolithLib

struct ValidatorTests {
    // MARK: - Project Name

    @Test
    func `valid project names`() {
        #expect(Validators.validateProjectName("MyApp"))
        #expect(Validators.validateProjectName("my-app"))
        #expect(Validators.validateProjectName("my_app"))
        #expect(Validators.validateProjectName("App123"))
        #expect(Validators.validateProjectName("A"))
    }

    @Test
    func `invalid project names - empty`() {
        #expect(!Validators.validateProjectName(""))
    }

    @Test
    func `invalid project names - starts with number`() {
        #expect(!Validators.validateProjectName("123App"))
    }

    @Test
    func `invalid project names - starts with hyphen`() {
        #expect(!Validators.validateProjectName("-app"))
    }

    @Test
    func `invalid project names - special characters`() {
        #expect(!Validators.validateProjectName("My App"))
        #expect(!Validators.validateProjectName("My.App"))
        #expect(!Validators.validateProjectName("My@App"))
    }

    @Test
    func `invalid project names - too long`() {
        let longName = String(repeating: "a", count: 51)
        #expect(!Validators.validateProjectName(longName))
    }

    @Test
    func `project name at max length`() {
        let maxName = "A" + String(repeating: "a", count: 49)
        #expect(Validators.validateProjectName(maxName))
    }

    // MARK: - Sanitize Project Name

    @Test
    func `sanitize project name strips spaces`() {
        #expect(Validators.sanitizeProjectName("My App") == "MyApp")
    }

    @Test
    func `sanitize project name strips special chars`() {
        #expect(Validators.sanitizeProjectName("My.App!") == "MyApp")
    }

    @Test
    func `sanitize project name strips leading digits`() {
        #expect(Validators.sanitizeProjectName("123App") == "App")
    }

    @Test
    func `sanitize project name trims to 50 chars`() {
        let longName = "A" + String(repeating: "b", count: 60)
        let result = Validators.sanitizeProjectName(longName)
        #expect(result.count == 50)
    }

    // MARK: - Bundle ID

    @Test
    func `valid bundle IDs`() {
        #expect(Validators.validateBundleID("com.example.app"))
        #expect(Validators.validateBundleID("com.my-company.my-app"))
        #expect(Validators.validateBundleID("io.github.user.project"))
        #expect(Validators.validateBundleID("com.example"))
    }

    @Test
    func `invalid bundle IDs - single segment`() {
        #expect(!Validators.validateBundleID("myapp"))
    }

    @Test
    func `invalid bundle IDs - empty segment`() {
        #expect(!Validators.validateBundleID("com..app"))
        #expect(!Validators.validateBundleID(".com.app"))
    }

    @Test
    func `invalid bundle IDs - segment starts with number`() {
        #expect(!Validators.validateBundleID("com.123.app"))
    }

    @Test
    func `invalid bundle IDs - special characters`() {
        #expect(!Validators.validateBundleID("com.example.my app"))
        #expect(!Validators.validateBundleID("com.example.my@app"))
    }

    @Test
    func `invalid bundle IDs - empty`() {
        #expect(!Validators.validateBundleID(""))
    }

    // MARK: - Hex Color

    @Test
    func `valid hex colors`() {
        #expect(Validators.validateHexColor("#4CAF7D"))
        #expect(Validators.validateHexColor("#000000"))
        #expect(Validators.validateHexColor("#FFFFFF"))
        #expect(Validators.validateHexColor("#ffffff"))
        #expect(Validators.validateHexColor("#4caf7d"))
        #expect(Validators.validateHexColor("#AbCdEf"))
    }

    @Test
    func `invalid hex colors - missing hash`() {
        #expect(!Validators.validateHexColor("4CAF7D"))
    }

    @Test
    func `invalid hex colors - wrong length`() {
        #expect(!Validators.validateHexColor("#4CA"))
        #expect(!Validators.validateHexColor("#4CAF7D00"))
    }

    @Test
    func `invalid hex colors - non-hex characters`() {
        #expect(!Validators.validateHexColor("#GGGGGG"))
        #expect(!Validators.validateHexColor("#4CAF7Z"))
    }

    @Test
    func `invalid hex colors - empty`() {
        #expect(!Validators.validateHexColor(""))
        #expect(!Validators.validateHexColor("#"))
    }

    // MARK: - Deployment Target

    @Test
    func `valid deployment targets`() {
        #expect(Validators.validateDeploymentTarget("18.0"))
        #expect(Validators.validateDeploymentTarget("18.4"))
        #expect(Validators.validateDeploymentTarget("19.0"))
    }

    @Test
    func `invalid deployment targets - below 18`() {
        #expect(!Validators.validateDeploymentTarget("17.0"))
        #expect(!Validators.validateDeploymentTarget("16.4"))
    }

    @Test
    func `invalid deployment targets - wrong format`() {
        #expect(!Validators.validateDeploymentTarget("18"))
        #expect(!Validators.validateDeploymentTarget("18.0.1"))
        #expect(!Validators.validateDeploymentTarget("abc"))
    }

    // MARK: - Default Bundle ID

    @Test
    func `default bundle ID from project name`() {
        #expect(Validators.defaultBundleID(for: "MyApp") == "com.example.myapp")
        #expect(Validators.defaultBundleID(for: "my_app") == "com.example.my-app")
    }

    // MARK: - Platform Version

    @Test
    func `valid platform versions`() {
        #expect(Validators.validatePlatformVersion("18.0"))
        #expect(Validators.validatePlatformVersion("15.0"))
        #expect(Validators.validatePlatformVersion("2.0"))
        #expect(Validators.validatePlatformVersion("19.4"))
    }

    @Test
    func `invalid platform version - non-numeric`() {
        #expect(!Validators.validatePlatformVersion("abc"))
        #expect(!Validators.validatePlatformVersion("18.x"))
    }

    @Test
    func `invalid platform version - single component`() {
        #expect(!Validators.validatePlatformVersion("18"))
    }

    @Test
    func `invalid platform version - empty`() {
        #expect(!Validators.validatePlatformVersion(""))
    }

    @Test
    func `invalid platform version - three components`() {
        #expect(!Validators.validatePlatformVersion("18.0.1"))
    }

    // MARK: - Tab Parsing

    @Test
    func `parse valid tabs`() {
        let tabs = PromptEngine.parseTabs("Home:house, Settings:gearshape")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
        #expect(tabs[1].name == "Settings")
        #expect(tabs[1].icon == "gearshape")
    }

    @Test
    func `parse single tab`() {
        let tabs = PromptEngine.parseTabs("Home:house")
        #expect(tabs.count == 1)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
    }

    @Test
    func `parse tabs with extra whitespace`() {
        let tabs = PromptEngine.parseTabs("  Home : house ,  Settings : gearshape  ")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
    }

    @Test
    func `parse empty tabs input`() {
        let tabs = PromptEngine.parseTabs("")
        #expect(tabs.isEmpty)
    }

    @Test
    func `parse tabs with invalid entries skipped`() {
        let tabs = PromptEngine.parseTabs("Home:house, invalid, Settings:gearshape")
        #expect(tabs.count == 2)
    }
}
