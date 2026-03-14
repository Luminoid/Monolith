import Foundation
import Testing
@testable import MonolithLib

@Suite("LocalizationGenerator")
struct LocalizationGeneratorTests {
    private func makeConfig(
        tabs: [TabDefinition] = [],
        localization: Bool = true
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if localization { features.insert(.localization) }
        return AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .spm,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test"
        )
    }

    // MARK: - String Catalog

    @Test("string catalog contains valid JSON structure")
    func stringCatalogStructure() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"sourceLanguage\": \"en\""))
        #expect(output.contains("\"version\": \"1.0\""))
        #expect(output.contains("\"strings\""))
    }

    @Test("string catalog contains app title key")
    func stringCatalogAppTitle() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"app.title\""))
        #expect(output.contains("\"TestApp\""))
    }

    @Test("string catalog contains common keys")
    func stringCatalogCommonKeys() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"common.ok\""))
        #expect(output.contains("\"common.cancel\""))
        #expect(output.contains("\"common.settings\""))
        #expect(output.contains("\"common.done\""))
        #expect(output.contains("\"common.error\""))
    }

    @Test("string catalog includes tab keys when tabs configured")
    func stringCatalogWithTabs() {
        let config = makeConfig(tabs: [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Settings", icon: "gear"),
        ])
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(output.contains("\"tab.home\""))
        #expect(output.contains("\"tab.settings\""))
    }

    @Test("string catalog has no tab keys without tabs")
    func stringCatalogWithoutTabs() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateStringCatalog(config: config)
        #expect(!output.contains("\"tab."))
    }

    // MARK: - L10n Helper

    @Test("L10n uses String(localized:) pattern")
    func l10nPattern() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(output.contains("String(localized: \"app.title\")"))
        #expect(output.contains("String(localized: \"common.ok\")"))
    }

    @Test("L10n contains enum declaration")
    func l10nEnum() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(output.contains("enum L10n {"))
        #expect(output.contains("import Foundation"))
    }

    @Test("L10n includes Tab enum when tabs configured")
    func l10nWithTabs() {
        let config = makeConfig(tabs: [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Profile", icon: "person"),
        ])
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(output.contains("enum Tab {"))
        #expect(output.contains("static let home = String(localized: \"tab.home\")"))
        #expect(output.contains("static let profile = String(localized: \"tab.profile\")"))
    }

    @Test("L10n has no Tab enum without tabs")
    func l10nWithoutTabs() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(!output.contains("enum Tab"))
    }
}
