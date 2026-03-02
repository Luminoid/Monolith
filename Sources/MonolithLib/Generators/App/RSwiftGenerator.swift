import Foundation

enum RSwiftGenerator {

    static func generateMintfile() -> String {
        "mac-cain13/R.swift@7.5.0"
    }

    static func generateBuildPhaseScript(config: AppConfig) -> String {
        """
        # R.swift Build Phase Script
        # Add as a "Run Script" build phase before "Compile Sources"
        if [ -f "$(which mint)" ]; then
            mint run r.swift rswift generate "$SRCROOT/\(config.name)/Generated/R.generated.swift"
        else
            echo "warning: Mint not found. Install with: brew install mint"
        fi
        """
    }
}
