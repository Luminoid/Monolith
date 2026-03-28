import Foundation
import Testing
@testable import MonolithLib

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
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test"
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
    func `L10n uses String(localized:) pattern`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(output.contains("String(localized: \"app.title\")"))
        #expect(output.contains("String(localized: \"common.ok\")"))
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
        #expect(output.contains("static let home = String(localized: \"tab.home\")"))
        #expect(output.contains("static let profile = String(localized: \"tab.profile\")"))
    }

    @Test
    func `L10n has no Tab enum without tabs`() {
        let config = makeConfig()
        let output = LocalizationGenerator.generateL10n(config: config)
        #expect(!output.contains("enum Tab"))
    }
}
