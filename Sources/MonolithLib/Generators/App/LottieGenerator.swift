import Foundation

/// Generates Lottie-related code and dependency configuration.
enum LottieGenerator {

    /// Generate a sample Lottie animation view helper.
    static func generateHelper(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Lottie")
        lines.append("import UIKit")
        lines.append("")
        lines.append("/// Helper for creating Lottie animation views.")
        lines.append("enum LottieHelper {")
        lines.append("")
        lines.append("    /// Create an animation view for a bundled animation file.")
        lines.append("    static func makeAnimationView(")
        lines.append("        named name: String,")
        lines.append("        loopMode: LottieLoopMode = .loop")
        lines.append("    ) -> LottieAnimationView {")
        lines.append("        let animationView = LottieAnimationView(name: name)")
        lines.append("        animationView.loopMode = loopMode")
        lines.append("        animationView.contentMode = .scaleAspectFit")
        lines.append("        return animationView")
        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
