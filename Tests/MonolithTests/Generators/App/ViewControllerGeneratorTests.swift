import Foundation
import Testing
@testable import MonolithLib

@Suite("ViewControllerGenerator")
struct ViewControllerGeneratorTests {
    private func makeConfig(
        lumiKit: Bool = false,
        snapKit: Bool = false,
        darkMode: Bool = false,
        localization: Bool = false,
        name: String = "TestApp",
        tabs: [TabDefinition] = []
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if lumiKit { features.insert(.lumiKit) }
        if snapKit { features.insert(.snapKit) }
        if darkMode { features.insert(.darkMode) }
        if localization { features.insert(.localization) }

        return AppConfig(
            name: name,
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

    // MARK: - Basic ViewController

    @Test("basic ViewController has UIKit import")
    func basicImports() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("import UIKit"))
        #expect(output.contains("class ViewController: UIViewController"))
    }

    @Test("uses lazy var for titleLabel")
    func lazyVarTitleLabel() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("private lazy var titleLabel: UILabel"))
    }

    @Test("has setupUI method called from viewDidLoad")
    func setupUIPattern() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("override func viewDidLoad()"))
        #expect(output.contains("setupUI()"))
        #expect(output.contains("private func setupUI()"))
    }

    @Test("default background is systemBackground")
    func defaultBackground() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("view.backgroundColor = .systemBackground"))
    }

    @Test("default uses NSLayoutConstraint")
    func defaultUsesNSLayoutConstraint() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("NSLayoutConstraint.activate"))
        #expect(output.contains("translatesAutoresizingMaskIntoConstraints = false"))
    }

    // MARK: - SnapKit

    @Test("SnapKit uses snp.makeConstraints")
    func snapKitConstraints() {
        let output = ViewControllerGenerator.generate(config: makeConfig(snapKit: true))
        #expect(output.contains("import SnapKit"))
        #expect(output.contains("snp.makeConstraints"))
        #expect(!output.contains("NSLayoutConstraint"))
    }

    // MARK: - LumiKit

    @Test("LumiKit uses design system tokens")
    func lumiKitTokens() {
        let output = ViewControllerGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("LMKColor.textPrimary"))
        #expect(output.contains("LMKColor.backgroundPrimary"))
    }

    @Test("LumiKit + SnapKit uses LMKSpacing for padding")
    func lumiKitSnapKitSpacing() {
        let output = ViewControllerGenerator.generate(config: makeConfig(lumiKit: true, snapKit: true))
        #expect(output.contains("LMKSpacing.cardPadding"))
    }

    @Test("LumiKit without SnapKit uses LMKSpacing for padding")
    func lumiKitWithoutSnapKitSpacing() {
        let output = ViewControllerGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("LMKSpacing.cardPadding"))
    }

    // MARK: - Dark Mode

    @Test("dark mode uses AppTheme colors")
    func darkModeColors() {
        let output = ViewControllerGenerator.generate(config: makeConfig(darkMode: true))
        #expect(output.contains("AppTheme.textPrimary"))
        #expect(output.contains("AppTheme.backgroundPrimary"))
    }

    // MARK: - Localization

    @Test("localization uses L10n")
    func localizationL10n() {
        let output = ViewControllerGenerator.generate(config: makeConfig(localization: true))
        #expect(output.contains("L10n.appTitle"))
    }

    @Test("without localization uses hardcoded name")
    func noLocalizationHardcodedName() {
        let output = ViewControllerGenerator.generate(config: makeConfig(name: "MyApp"))
        #expect(output.contains("\"MyApp\""))
    }

    // MARK: - Tab ViewControllers

    @Test("tab VC uses tab name as class name")
    func tabVCClassName() {
        let tab = TabDefinition(name: "Home", icon: "house")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig())
        #expect(output.contains("class HomeViewController: UIViewController"))
    }

    @Test("tab VC sets title")
    func tabVCTitle() {
        let tab = TabDefinition(name: "Settings", icon: "gear")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig())
        #expect(output.contains("title = \"Settings\""))
    }

    @Test("tab VC with localization uses L10n.Tab")
    func tabVCLocalized() {
        let tab = TabDefinition(name: "Home", icon: "house")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig(localization: true))
        #expect(output.contains("L10n.Tab.home"))
    }

    // MARK: - MARK Comments

    @Test("MARK comments present")
    func markComments() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Properties"))
        #expect(output.contains("// MARK: - Lifecycle"))
        #expect(output.contains("// MARK: - Setup"))
    }
}
