import Foundation
import Testing
@testable import MonolithLib

struct LocalizationGeneratorTests {
    private func makeConfig(
        tabs: [TabDefinition] = [],
        localization: Bool = true,
        macCatalyst: Bool = false,
        locales: [String] = ["en"]
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if localization { features.insert(.localization) }
        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }
        return AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary,
            locales: locales
        )
    }

    // MARK: - String Catalog

    @Test
    func `string catalog contains valid JSON structure`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"sourceLanguage\": \"en\""))
        #expect(output.contains("\"version\": \"1.0\""))
        #expect(output.contains("\"strings\""))
    }

    @Test
    func `string catalog contains app title key`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"app.title\""))
        #expect(output.contains("\"TestApp\""))
    }

    // Regression: the View menu (and its localized ⌘R Refresh) exists on every
    // idiom whenever the app has tabs, but the catalog carried `menu.refresh`
    // only for Mac Catalyst, with a comment the menu didn't use. The catalog
    // entry now follows the tabs and matches the menu's inline lookup; nothing
    // reads an `L10n.Menu` constant, so none is emitted.
    @Test
    func `menu refresh key follows the tabs and matches the menu lookup`() {
        let tabs = [TabDefinition(name: "Home", icon: "house"), TabDefinition(name: "Settings", icon: "gear")]
        let tabbed = makeConfig(tabs: tabs)
        let catalog = LocalizationGenerator.generateStringCatalog(config: tabbed)
        let refresh = AppDelegateGenerator.refreshCommandTitle
        #expect(catalog.contains("\"\(refresh.key)\": {\n            \"comment\": \"\(refresh.comment)\""))
        #expect(catalog.contains("\"value\": \"\(refresh.value)\""))
        #expect(!LocalizationGenerator.generateL10n(config: tabbed).contains("enum Menu"))

        let delegate = AppDelegateGenerator.generate(config: tabbed)
        #expect(delegate.contains("String(localized: \"\(refresh.key)\", defaultValue: \"\(refresh.value)\", comment: \"\(refresh.comment)\")"))

        let macWithoutTabs = makeConfig(macCatalyst: true)
        #expect(!LocalizationGenerator.generateStringCatalog(config: macWithoutTabs).contains("menu.refresh"))
        #expect(!AppDelegateGenerator.generate(config: macWithoutTabs).contains("buildMenu"))
    }

    @Test
    func `string catalog contains common keys`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"common.ok\""))
        #expect(output.contains("\"common.cancel\""))
        #expect(output.contains("\"common.settings\""))
        #expect(output.contains("\"common.done\""))
        #expect(output.contains("\"common.error\""))
    }

    @Test
    func `string catalog includes tab keys when tabs configured`() {
        let config = makeConfig(tabs: [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Settings", icon: "gear"),
        ])
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"tab.home\""))
        #expect(output.contains("\"tab.settings\""))
    }

    @Test
    func `string catalog has no tab keys without tabs`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(!output.contains("\"tab."))
    }

    // MARK: - L10n Helper

    @Test
    func `L10n uses String(localized:defaultValue:comment:)`() {
        // The default value is the source text, so a key missing from the
        // catalog still reads as words; the comment gives translators context.
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(output.contains("static let appTitle = String(localized: \"app.title\", defaultValue: \"TestApp\", comment: \"The app's name\")"))
        #expect(output.contains("static let ok = String(localized: \"common.ok\", defaultValue: \"OK\", comment: \"Button that accepts an alert\")"))
        // Every constant carries both.
        let constants = output.components(separatedBy: "\n").filter { $0.contains("String(localized:") }
        #expect(constants.count == 6)
        #expect(constants.allSatisfy { $0.contains(", defaultValue: \"") && $0.contains(", comment: \"") })
    }

    @Test
    func `catalog comments match the L10n comments`() throws {
        // Xcode writes the code's comment into the catalog on extraction; the
        // generated catalog already has it, so the first build changes nothing.
        // The code reading a key is its L10n constant, or for the View menu's
        // Refresh title, AppDelegate's inline lookup.
        let config = makeConfig(tabs: [TabDefinition(name: "Home", icon: "house.fill")], macCatalyst: true)
        let catalog = LocalizationGenerator.generateStringCatalog(config: config)
        let code = LocalizationGenerator.generateL10n(config: config) + AppDelegateGenerator.generate(config: config)
        let json = try #require(try JSONSerialization.jsonObject(with: Data(catalog.utf8)) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: [String: Any]])
        #expect(strings.count == 8)
        for (key, entry) in strings {
            let comment = try #require(entry["comment"] as? String, "\(key) has no comment")
            let lookup = code.components(separatedBy: "\n").first { $0.contains("String(localized: \"\(key)\", defaultValue: ") }
            #expect(lookup != nil, "no code reads \(key)")
            #expect(lookup?.contains(", comment: \"\(comment)\")") == true, "\(key) comment differs from the code")
        }
    }

    @Test
    func `L10n contains enum declaration`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(output.contains("enum L10n {"))
        #expect(output.contains("import Foundation"))
    }

    @Test
    func `L10n includes Tab enum when tabs configured`() {
        let config = makeConfig(tabs: [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Profile", icon: "person"),
        ])
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(output.contains("enum Tab {"))
        #expect(output.contains("static let home = String(localized: \"tab.home\", defaultValue: \"Home\", comment: \"Tab bar title\")"))
        #expect(output.contains("static let profile = String(localized: \"tab.profile\", defaultValue: \"Profile\", comment: \"Tab bar title\")"))
    }

    @Test
    func `L10n has no Tab enum without tabs`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(!output.contains("enum Tab"))
    }

    // MARK: - Multi-Locale Catalog

    @Test
    func `string catalog uses first locale as sourceLanguage`() {
        let config = makeConfig(locales: ["en", "zh-Hans", "es"])
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"sourceLanguage\": \"en\""))
    }

    @Test
    func `string catalog emits every locale entry per key`() {
        let config = makeConfig(locales: ["en", "zh-Hans", "es"])
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        // Each of the 6 default keys × 3 locales = 18 stringUnits.
        let stringUnitCount = output.components(separatedBy: "\"stringUnit\":").count - 1
        #expect(stringUnitCount == 18, "expected 18 stringUnits (6 keys × 3 locales), got \(stringUnitCount)")
        #expect(output.contains("\"en\":"))
        #expect(output.contains("\"zh-Hans\":"))
        #expect(output.contains("\"es\":"))
    }

    @Test
    func `source-locale entries are translated, non-source are new`() {
        // Source locale (first) is marked translated so the audit doesn't
        // flag it; non-source locales start as `new` so the audit surfaces
        // them as outstanding translation work.
        let config = makeConfig(locales: ["en", "zh-Hans"])
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        let translatedCount = output.components(separatedBy: "\"state\": \"translated\"").count - 1
        let newCount = output.components(separatedBy: "\"state\": \"new\"").count - 1
        // 6 keys × 1 source locale = 6 translated; 6 keys × 1 non-source = 6 new.
        #expect(translatedCount == 6)
        #expect(newCount == 6)
    }

    @Test
    func `string catalog falls back to en when locales is empty`() {
        let config = makeConfig(locales: [])
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"sourceLanguage\": \"en\""))
        #expect(output.contains("\"en\":"))
    }
}
