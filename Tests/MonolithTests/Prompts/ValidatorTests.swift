import Foundation
import Testing
@testable import MonolithLib

struct ValidatorTests {
    // MARK: - Project Name

    @Test
    func `valid app names are Swift identifiers`() {
        #expect(Validators.validateProjectName("MyApp", kind: .app))
        #expect(Validators.validateProjectName("my_app", kind: .app))
        #expect(Validators.validateProjectName("App123", kind: .app))
        #expect(Validators.validateProjectName("A", kind: .app))
    }

    /// Regression: `new app --name my-app` emitted `final class my-appCoreDataStack`
    /// and `@testable import my-app`, neither of which compiles.
    @Test
    func `app names reject hyphens`() {
        #expect(!Validators.validateProjectName("my-app", kind: .app))
        let problem = Validators.projectNameProblem("my-app", kind: .app)
        #expect(problem?.contains("Swift identifiers") == true)
        #expect(problem?.contains("MyApp") == true)
    }

    @Test
    func `package and CLI names allow hyphens`() {
        #expect(Validators.validateProjectName("my-lib", kind: .package))
        #expect(Validators.validateProjectName("my-tool", kind: .cli))
        #expect(Validators.validateProjectName("my_tool2", kind: .cli))
    }

    @Test(arguments: [ProjectType.app, .package, .cli])
    func `names must be ASCII`(kind: ProjectType) {
        #expect(!Validators.validateProjectName("Café", kind: kind))
        #expect(!Validators.validateProjectName("Ünit", kind: kind))
        #expect(!Validators.validateProjectName("应用", kind: kind))
    }

    @Test(arguments: [ProjectType.app, .package, .cli])
    func `invalid project names - empty`(kind: ProjectType) {
        #expect(!Validators.validateProjectName("", kind: kind))
        #expect(Validators.projectNameProblem("", kind: kind)?.contains("empty") == true)
    }

    @Test(arguments: [ProjectType.app, .package, .cli])
    func `invalid project names - starts with number or hyphen`(kind: ProjectType) {
        #expect(!Validators.validateProjectName("123App", kind: kind))
        #expect(!Validators.validateProjectName("-app", kind: kind))
        #expect(!Validators.validateProjectName("_app", kind: kind))
    }

    /// Names reach the file system as the output directory, so a path
    /// separator or `..` must never pass.
    @Test(arguments: [ProjectType.app, .package, .cli])
    func `invalid project names - special characters and paths`(kind: ProjectType) {
        #expect(!Validators.validateProjectName("My App", kind: kind))
        #expect(!Validators.validateProjectName("My.App", kind: kind))
        #expect(!Validators.validateProjectName("My@App", kind: kind))
        #expect(!Validators.validateProjectName("../escaped", kind: kind))
        #expect(!Validators.validateProjectName("a/b", kind: kind))
    }

    @Test
    func `invalid project names - too long`() {
        let longName = String(repeating: "a", count: 51)
        #expect(!Validators.validateProjectName(longName, kind: .app))
        #expect(!Validators.validateProjectName(longName, kind: .package))
    }

    @Test
    func `project name at max length`() {
        let maxName = "A" + String(repeating: "a", count: 49)
        #expect(Validators.validateProjectName(maxName, kind: .app))
    }

    @Test(arguments: [ProjectType.app, .package, .cli])
    func `invalid project names - Swift reserved words`(kind: ProjectType) {
        // Keyword case — `class` as a struct name would not compile.
        #expect(!Validators.validateProjectName("class", kind: kind))
        #expect(!Validators.validateProjectName("protocol", kind: kind))
        #expect(!Validators.validateProjectName("Self", kind: kind))
        #expect(!Validators.validateProjectName("Type", kind: kind))
        // Built-in stdlib types — shadowing makes generated code unreadable.
        #expect(!Validators.validateProjectName("String", kind: kind))
        #expect(!Validators.validateProjectName("Never", kind: kind))
        // Concurrency keywords frequently used in code.
        #expect(!Validators.validateProjectName("actor", kind: kind))
        #expect(!Validators.validateProjectName("Sendable", kind: kind))
        #expect(Validators.projectNameProblem("class", kind: kind)?.contains("reserved word") == true)
    }

    @Test
    func `valid project names - case differs from reserved word`() {
        // `class` is reserved; `Class` is a legal identifier.
        #expect(Validators.validateProjectName("Class", kind: .app))
        #expect(Validators.validateProjectName("MyString", kind: .app))
        #expect(Validators.validateProjectName("Stringly", kind: .app))
    }

    @Test
    func `name rule names each kind's example`() {
        #expect(Validators.projectNameRule(for: .app).contains("MyApp"))
        #expect(Validators.projectNameRule(for: .package).contains("hyphens"))
        #expect(Validators.projectNameRule(for: .cli).contains("my-tool"))
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

    /// Regression: `CharacterSet.alphanumerics` let non-ASCII letters through,
    /// which App Store Connect and code signing reject.
    @Test
    func `invalid bundle IDs - non-ASCII and underscores`() {
        #expect(!Validators.validateBundleID("com.example.café"))
        #expect(!Validators.validateBundleID("com.exämple.app"))
        #expect(!Validators.validateBundleID("com.example.my_app"))
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
    func `invalid deployment targets - below the default major`() {
        #expect(Validators.minimumDeploymentMajor == 18)
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

    // MARK: - Locale

    @Test
    func `valid locales`() {
        for locale in ["en", "zh-Hans", "pt_BR", "es-419", "zh-Hant-TW", "fil"] {
            #expect(Validators.validateLocale(locale), "\(locale)")
        }
    }

    @Test
    func `invalid locales`() {
        for locale in ["", "e", "english", "en-", "en US", "zh-Hans!", "1en"] {
            #expect(!Validators.validateLocale(locale), "\(locale)")
        }
    }

    // MARK: - Tab Parsing

    @Test
    func `parse valid tabs`() throws {
        let tabs = try TabDefinition.parseList("Home:house, Settings:gearshape")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
        #expect(tabs[1].name == "Settings")
        #expect(tabs[1].icon == "gearshape")
    }

    @Test
    func `parse single tab`() throws {
        let tabs = try TabDefinition.parseList("Home:house")
        #expect(tabs.count == 1)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
    }

    @Test
    func `parse tabs with extra whitespace`() throws {
        let tabs = try TabDefinition.parseList("  Home : house ,  Settings : gearshape  ")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
    }

    @Test
    func `parse empty tabs input`() throws {
        #expect(try TabDefinition.parseList("").isEmpty)
        #expect(try TabDefinition.parseList(nil).isEmpty)
    }

    /// Regression: `--tabs Home` (no icon) was dropped without a word.
    @Test
    func `parse tabs rejects an entry without an icon or name`() {
        for input in ["Home", "Home:house, invalid", "Home:", ":house"] {
            #expect(throws: ConfigValidationError.self, "\(input)") { try TabDefinition.parseList(input) }
        }
    }
}
