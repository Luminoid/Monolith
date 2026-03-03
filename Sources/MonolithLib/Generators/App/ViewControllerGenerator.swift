import Foundation

enum ViewControllerGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import UIKit")
        if config.hasLumiKit {
            lines.append("import LumiKitUI")
        }
        if config.hasSnapKit {
            lines.append("import SnapKit")
        }
        lines.append("")

        lines.append("class ViewController: UIViewController {")
        lines.append("")

        lines.addMark("Properties")

        // Title label
        lines.append("    private lazy var titleLabel: UILabel = {")
        lines.append("        let label = UILabel()")
        if config.hasLumiKit {
            lines.append("        label.font = .preferredFont(forTextStyle: .largeTitle)")
            lines.append("        label.textColor = LMKColor.textPrimary")
        } else if config.hasDarkMode {
            lines.append("        label.font = .preferredFont(forTextStyle: .largeTitle)")
            lines.append("        label.textColor = AppTheme.textPrimary")
        } else {
            lines.append("        label.font = .preferredFont(forTextStyle: .largeTitle)")
            lines.append("        label.textColor = .label")
        }
        if config.hasLocalization {
            lines.append("        label.text = L10n.appTitle")
        } else {
            lines.append("        label.text = \"\(config.name)\"")
        }
        lines.append("        label.textAlignment = .center")
        lines.append("        return label")
        lines.append("    }()")
        lines.append("")

        lines.addMark("Lifecycle")
        lines.append("    override func viewDidLoad() {")
        lines.append("        super.viewDidLoad()")
        lines.append("        setupUI()")
        lines.append("    }")

        lines.addMark("Setup")
        lines.append("    private func setupUI() {")
        if config.hasLumiKit {
            lines.append("        view.backgroundColor = LMKColor.backgroundPrimary")
        } else if config.hasDarkMode {
            lines.append("        view.backgroundColor = AppTheme.backgroundPrimary")
        } else {
            lines.append("        view.backgroundColor = .systemBackground")
        }
        lines.append("")
        lines.append("        view.addSubview(titleLabel)")

        if config.hasSnapKit {
            let padding = config.hasLumiKit ? "LMKSpacing.cardPadding" : "16"
            lines.append("        titleLabel.snp.makeConstraints { make in")
            lines.append("            make.center.equalToSuperview()")
            lines.append("            make.leading.trailing.equalToSuperview().inset(\(padding))")
            lines.append("        }")
        } else {
            let padding = config.hasLumiKit ? "LMKSpacing.cardPadding" : "16"
            lines.append("        titleLabel.translatesAutoresizingMaskIntoConstraints = false")
            lines.append("        NSLayoutConstraint.activate([")
            lines.append("            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),")
            lines.append("            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),")
            lines.append("            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: \(padding)),")
            lines.append("            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -\(padding)),")
            lines.append("        ])")
        }

        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Generate a feature-specific view controller for a tab.
    static func generateForTab(_ tab: TabDefinition, config: AppConfig) -> String {
        var lines: [String] = []
        let className = "\(tab.name)ViewController"

        lines.append("import UIKit")
        if config.hasLumiKit {
            lines.append("import LumiKitUI")
        }
        if config.hasSnapKit {
            lines.append("import SnapKit")
        }
        lines.append("")

        lines.append("class \(className): UIViewController {")
        lines.append("")
        lines.append("    // MARK: - Lifecycle")
        lines.append("")
        lines.append("    override func viewDidLoad() {")
        lines.append("        super.viewDidLoad()")
        if config.hasLocalization {
            let propertyName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
            lines.append("        title = L10n.Tab.\(propertyName)")
        } else {
            lines.append("        title = \"\(tab.name)\"")
        }

        if config.hasLumiKit {
            lines.append("        view.backgroundColor = LMKColor.backgroundPrimary")
        } else if config.hasDarkMode {
            lines.append("        view.backgroundColor = AppTheme.backgroundPrimary")
        } else {
            lines.append("        view.backgroundColor = .systemBackground")
        }

        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
