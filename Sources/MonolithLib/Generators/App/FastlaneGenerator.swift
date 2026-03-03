import Foundation

enum FastlaneGenerator {
    static func generateGemfile() -> String {
        """
        source "https://rubygems.org"

        gem "fastlane"
        """
    }

    static func generateAppfile(config: AppConfig) -> String {
        """
        app_identifier "\(config.bundleID)"
        # apple_id "your@email.com"
        # team_id "TEAM_ID"
        """
    }

    static func generateFastfile(config: AppConfig) -> String {
        """
        default_platform(:ios)

        platform :ios do
          desc "Run tests"
          lane :test do
            run_tests(
              scheme: "\(config.name)",
              devices: ["iPhone 17"]
            )
          end

          desc "Build for TestFlight"
          lane :beta do
            build_app(
              scheme: "\(config.name)",
              export_options: "ExportOptions.plist"
            )
            upload_to_testflight
          end
        end
        """
    }
}
