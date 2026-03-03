enum DesignSystemGenerator {
    static func generate() -> String {
        """
        import UIKit

        /// App-specific design system extensions.
        /// Extends the base design system (LumiKit or standalone) with app-specific tokens.
        enum DesignSystem {

            // MARK: - Cell

            enum Cell {
                static let defaultHeight: CGFloat = 60
                static let compactHeight: CGFloat = 44
            }

            // MARK: - Layout

            enum Layout {
                static let cardCornerRadius: CGFloat = 12
                static let buttonCornerRadius: CGFloat = 8
                static let iconSize: CGFloat = 24
            }
        }

        """
    }
}
