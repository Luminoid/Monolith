import Foundation

/// Generates the root `ViewController` of a tab-less app and one view
/// controller per tab.
///
/// Both take the app's `ModelContainer` in `init` when the app uses
/// SwiftData. Text follows Dynamic Type, spacing comes from design tokens,
/// and content is pinned to the safe area (which also clears an iPad or Mac
/// sidebar floating over the content).
enum ViewControllerGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        if config.hasLumiKit {
            lines.append("import LumiKitUI")
        }
        if config.hasSnapKit {
            lines.append("import SnapKit")
        }
        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
        lines.append("")

        lines.append("final class ViewController: UIViewController {")

        lines.addMark("Properties")
        if config.hasSwiftData {
            lines.append(modelContainerProperty)
            lines.append("")
        }
        lines.append(contentsOf: titleLabel(config: config))

        if config.hasSwiftData {
            lines.addMark("Initialization")
            lines.append(modelContainerInit)
        }

        lines.addMark("Lifecycle")
        lines.append("""
            override func viewDidLoad() {
                super.viewDidLoad()
                setupUI()
            }
        """)

        lines.addMark("Setup")
        lines.append("    private func setupUI() {")
        lines.append("        view.backgroundColor = \(backgroundColor(config: config))")
        lines.append("")
        lines.append("        view.addSubview(titleLabel)")

        let padding = config.hasLumiKit ? "LMKSpacing.cardPadding" : "DesignSystem.Layout.cardPadding"
        if config.hasSnapKit {
            lines.append("        titleLabel.snp.makeConstraints { make in")
            lines.append("            make.centerY.equalTo(view.safeAreaLayoutGuide)")
            lines.append("            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(\(padding))")
            lines.append("        }")
        } else {
            lines.append("        let safeArea = view.safeAreaLayoutGuide")
            lines.append("        titleLabel.translatesAutoresizingMaskIntoConstraints = false")
            lines.append("        NSLayoutConstraint.activate([")
            lines.append("            titleLabel.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),")
            lines.append("            titleLabel.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: \(padding)),")
            lines.append("            titleLabel.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -\(padding)),")
            lines.append("        ])")
        }

        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Generate a feature-specific view controller for a tab: a titled screen
    /// with a placeholder (the tab's symbol and name) until it has content.
    static func generateForTab(_ tab: TabDefinition, config: AppConfig) -> String {
        var lines: [String] = []
        let className = "\(tab.name)ViewController"
        let title = config.hasLocalization ? "L10n.Tab.\(AppConstantsGenerator.caseName(for: tab))" : "\"\(tab.name)\""

        // SnapKit pins the LumiKit empty state; the plain placeholder is a
        // content-unavailable configuration and needs no layout code.
        if config.hasLumiKit {
            lines.append("import LumiKitUI")
            lines.append("import SnapKit")
        }
        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
        lines.append("")

        lines.append("final class \(className): UIViewController {")

        if config.hasSwiftData || config.hasLumiKit {
            lines.addMark("Properties")
        }
        if config.hasSwiftData {
            lines.append(modelContainerProperty)
        }
        if config.hasLumiKit {
            if config.hasSwiftData {
                lines.append("")
            }
            lines.append("""
                /// Shown until the screen has content.
                private lazy var emptyStateView: LMKEmptyStateView = {
                    let emptyState = LMKEmptyStateView()
                    emptyState.configure(LMKEmptyStateView.Content(message: \(title), icon: .system("\(tab.icon)")), animated: false)
                    return emptyState
                }()
            """)
        }

        if config.hasSwiftData {
            lines.addMark("Initialization")
            lines.append(modelContainerInit)
        }

        lines.addMark("Lifecycle")
        lines.append("    override func viewDidLoad() {")
        lines.append("        super.viewDidLoad()")
        lines.append("        title = \(title)")
        lines.append("        view.backgroundColor = \(backgroundColor(config: config))")
        if config.hasLumiKit {
            lines.append("""

                    view.addSubview(emptyStateView)
                    emptyStateView.snp.makeConstraints { make in
                        make.edges.equalTo(view.safeAreaLayoutGuide)
                    }
            """)
        } else {
            lines.append("""

                    // Shown until the screen has content.
                    var placeholder = UIContentUnavailableConfiguration.empty()
                    placeholder.image = UIImage(systemName: "\(tab.icon)")
                    placeholder.text = \(title)
                    contentUnavailableConfiguration = placeholder
            """)
        }
        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func backgroundColor(config: AppConfig) -> String {
        if config.hasLumiKit {
            return "LMKColor.backgroundPrimary"
        }
        return config.hasDarkMode ? "AppTheme.backgroundPrimary" : ".systemBackground"
    }

    /// The sample title: Dynamic Type, wrapping instead of truncating.
    private static func titleLabel(config: AppConfig) -> [String] {
        var lines: [String] = []
        let text = config.hasLocalization ? "L10n.appTitle" : "\"\(config.name)\""
        lines.append("    private lazy var titleLabel: UILabel = {")
        if config.hasLumiKit {
            // `lmk_make` applies the theme's Dynamic Type font, re-applies it
            // when the text size changes, and wraps (`numberOfLines = 0`).
            lines.append("        let label = UILabel.lmk_make(.h1, text: \(text), color: LMKColor.textPrimary)")
        } else {
            lines.append("        let label = UILabel()")
            lines.append("        label.font = .preferredFont(forTextStyle: .largeTitle)")
            lines.append("        label.adjustsFontForContentSizeCategory = true")
            lines.append("        label.numberOfLines = 0")
            lines.append("        label.textColor = \(config.hasDarkMode ? "AppTheme.textPrimary" : ".label")")
            lines.append("        label.text = \(text)")
        }
        lines.append("        label.textAlignment = .center")
        lines.append("        return label")
        lines.append("    }()")
        return lines
    }

    private static let modelContainerProperty = """
        /// The app's SwiftData container; make a `ModelContext` from it for this screen's data.
        private let modelContainer: ModelContainer
    """

    private static let modelContainerInit = """
        init(modelContainer: ModelContainer) {
            self.modelContainer = modelContainer
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    """
}
