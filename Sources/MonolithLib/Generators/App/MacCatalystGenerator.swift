enum MacCatalystGenerator {
    /// Generate Mac Catalyst window configuration extension.
    static func generateWindowConfig() -> String {
        """
        import UIKit

        // MARK: - Mac Catalyst Window Configuration

        #if targetEnvironment(macCatalyst)
        enum MacWindowConfig {

            static func configure(_ windowScene: UIWindowScene) {
                if let titlebar = windowScene.titlebar {
                    titlebar.titleVisibility = .hidden
                    titlebar.toolbar = nil
                }
                windowScene.sizeRestrictions?.minimumSize = CGSize(
                    width: AppConstants.MacWindow.minWidth,
                    height: AppConstants.MacWindow.minHeight
                )
                windowScene.sizeRestrictions?.maximumSize = CGSize(
                    width: AppConstants.MacWindow.maxWidth,
                    height: AppConstants.MacWindow.maxHeight
                )
            }
        }
        #endif

        """
    }
}
