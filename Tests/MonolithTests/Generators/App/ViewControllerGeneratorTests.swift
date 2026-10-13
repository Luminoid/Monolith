import Foundation
import Testing
@testable import MonolithLib

struct ViewControllerGeneratorTests {
    private func makeConfig(
        lumiKit: Bool = false,
        snapKit: Bool = false,
        darkMode: Bool = false,
        localization: Bool = false,
        swiftData: Bool = false,
        name: String = "TestApp",
        tabs: [TabDefinition] = []
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if lumiKit { features.insert(.lumiKit) }
        if darkMode { features.insert(.darkMode) }
        if localization { features.insert(.localization) }
        if swiftData { features.insert(.swiftData) }

        var externalPackages: [ExternalPackage] = []
        var targetDeps: [String] = []
        if snapKit, let entry = KnownPackages.registry["SnapKit"] {
            externalPackages.append(ExternalPackage(name: entry.name, url: entry.url, requirement: "from: \"\(entry.defaultVersion)\"", packageName: nil))
            targetDeps.append("SnapKit")
        }

        return AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary,
            externalPackages: externalPackages,
            targetDependencies: targetDeps
        )
    }

    // MARK: - Basic ViewController

    @Test
    func `basic ViewController has UIKit import`() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("import UIKit"))
        #expect(output.contains("class ViewController: UIViewController"))
    }

    @Test
    func `uses lazy var for titleLabel`() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("private lazy var titleLabel: UILabel"))
    }

    @Test
    func `has setupUI method called from viewDidLoad`() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("override func viewDidLoad()"))
        #expect(output.contains("setupUI()"))
        #expect(output.contains("private func setupUI()"))
    }

    @Test
    func `default background is systemBackground`() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("view.backgroundColor = .systemBackground"))
    }

    @Test
    func `default uses NSLayoutConstraint`() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("NSLayoutConstraint.activate"))
        #expect(output.contains("translatesAutoresizingMaskIntoConstraints = false"))
    }

    /// The title follows Dynamic Type and wraps instead of truncating.
    @Test
    func `plain title label follows Dynamic Type`() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("label.font = .preferredFont(forTextStyle: .largeTitle)"))
        #expect(output.contains("label.adjustsFontForContentSizeCategory = true"))
        #expect(output.contains("label.numberOfLines = 0"))
    }

    /// Spacing comes from the design system and the label is pinned to the
    /// safe area (which also clears a floating iPad or Mac sidebar).
    @Test(arguments: [false, true])
    func `plain title label uses the padding token and the safe area`(snapKit: Bool) {
        let output = ViewControllerGenerator.generate(config: makeConfig(snapKit: snapKit))
        #expect(output.contains("DesignSystem.Layout.cardPadding"))
        #expect(!output.contains("16"))
        #expect(!output.contains("equalToSuperview"))
        #expect(!output.contains("view.leadingAnchor"))
        if snapKit {
            #expect(output.contains("make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(DesignSystem.Layout.cardPadding)"))
        } else {
            #expect(output.contains("let safeArea = view.safeAreaLayoutGuide"))
            #expect(output.contains("titleLabel.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: DesignSystem.Layout.cardPadding),"))
            #expect(output.contains("titleLabel.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -DesignSystem.Layout.cardPadding),"))
        }
    }

    // MARK: - SnapKit

    @Test
    func `SnapKit uses snp.makeConstraints`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(snapKit: true))
        #expect(output.contains("import SnapKit"))
        #expect(output.contains("snp.makeConstraints"))
        #expect(!output.contains("NSLayoutConstraint"))
    }

    // MARK: - LumiKit

    @Test
    func `LumiKit uses design system tokens`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("LMKColor.textPrimary"))
        #expect(output.contains("LMKColor.backgroundPrimary"))
    }

    /// `lmk_make` applies the theme's Dynamic Type font, re-applies it when the
    /// text size changes, and wraps.
    @Test
    func `LumiKit title label comes from the Dynamic Type label factory`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("let label = UILabel.lmk_make(.h1, text: \"TestApp\", color: LMKColor.textPrimary)"))
        #expect(!output.contains("preferredFont"))
        #expect(output.contains("make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(LMKSpacing.cardPadding)"))
    }

    @Test
    func `SwiftData root takes the container in init`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("    private let modelContainer: ModelContainer"))
        #expect(output.contains("    init(modelContainer: ModelContainer) {\n        self.modelContainer = modelContainer\n        super.init(nibName: nil, bundle: nil)\n    }"))
        #expect(output.contains("@available(*, unavailable)"))
        let plain = ViewControllerGenerator.generate(config: makeConfig())
        #expect(!plain.contains("modelContainer"))
        #expect(!plain.contains("import SwiftData"))
    }

    @Test
    func `LumiKit + SnapKit uses LMKSpacing for padding`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(lumiKit: true, snapKit: true))
        #expect(output.contains("LMKSpacing.cardPadding"))
    }

    @Test
    func `LumiKit without SnapKit uses LMKSpacing for padding`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("LMKSpacing.cardPadding"))
    }

    // MARK: - Dark Mode

    @Test
    func `dark mode uses AppTheme colors`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(darkMode: true))
        #expect(output.contains("AppTheme.textPrimary"))
        #expect(output.contains("AppTheme.backgroundPrimary"))
    }

    // MARK: - Localization

    @Test
    func `localization uses L10n`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(localization: true))
        #expect(output.contains("L10n.appTitle"))
    }

    @Test
    func `without localization uses hardcoded name`() {
        let output = ViewControllerGenerator.generate(config: makeConfig(name: "MyApp"))
        #expect(output.contains("\"MyApp\""))
    }

    // MARK: - Tab ViewControllers

    @Test
    func `tab VC uses tab name as class name`() {
        let tab = TabDefinition(name: "Home", icon: "house")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig())
        #expect(output.contains("class HomeViewController: UIViewController"))
    }

    @Test
    func `tab VC sets title`() {
        let tab = TabDefinition(name: "Settings", icon: "gear")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig())
        #expect(output.contains("title = \"Settings\""))
    }

    @Test
    func `tab VC with localization uses L10n.Tab`() {
        let tab = TabDefinition(name: "Home", icon: "house")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig(localization: true))
        #expect(output.contains("L10n.Tab.home"))
    }

    /// A blank screen gives no hint which tab it is; a placeholder shows the
    /// tab's symbol and name until the screen has content.
    @Test
    func `plain tab VC shows a content-unavailable placeholder`() {
        let tab = TabDefinition(name: "Home", icon: "house")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig())
        #expect(output.contains("var placeholder = UIContentUnavailableConfiguration.empty()"))
        #expect(output.contains("placeholder.image = UIImage(systemName: \"house\")"))
        #expect(output.contains("placeholder.text = \"Home\""))
        #expect(output.contains("contentUnavailableConfiguration = placeholder"))
        // Nothing lays out views, so SnapKit isn't imported even when available.
        let withSnapKit = ViewControllerGenerator.generateForTab(tab, config: makeConfig(snapKit: true))
        #expect(!withSnapKit.contains("import SnapKit"))
    }

    @Test
    func `LumiKit tab VC shows an empty state pinned to the safe area`() {
        let tab = TabDefinition(name: "Home", icon: "house")
        let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig(lumiKit: true))
        #expect(output.contains("import SnapKit"))
        #expect(output.contains("private lazy var emptyStateView: LMKEmptyStateView = {"))
        #expect(output.contains("emptyState.configure(LMKEmptyStateView.Content(message: \"Home\", icon: .system(\"house\")), animated: false)"))
        #expect(output.contains("make.edges.equalTo(view.safeAreaLayoutGuide)"))
    }

    @Test
    func `SwiftData tab VC takes the container in init`() {
        let tab = TabDefinition(name: "Home", icon: "house")
        for lumiKit in [false, true] {
            let output = ViewControllerGenerator.generateForTab(tab, config: makeConfig(lumiKit: lumiKit, swiftData: true))
            #expect(output.contains("import SwiftData"))
            #expect(output.contains("    init(modelContainer: ModelContainer) {"))
            #expect(output.contains("    private let modelContainer: ModelContainer"))
        }
    }

    // MARK: - MARK Comments

    @Test
    func `MARK comments present`() {
        let output = ViewControllerGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Properties"))
        #expect(output.contains("// MARK: - Lifecycle"))
        #expect(output.contains("// MARK: - Setup"))
    }
}
