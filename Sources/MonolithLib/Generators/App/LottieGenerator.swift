/// Generates Lottie-related code and dependency configuration.
enum LottieGenerator {

    /// Generate a sample Lottie animation view helper.
    static func generateHelper() -> String {
        """
        import Lottie
        import UIKit

        /// Helper for creating Lottie animation views.
        enum LottieHelper {

            /// Create an animation view for a bundled animation file.
            static func makeAnimationView(
                named name: String,
                loopMode: LottieLoopMode = .loop
            ) -> LottieAnimationView {
                let animationView = LottieAnimationView(name: name)
                animationView.loopMode = loopMode
                animationView.contentMode = .scaleAspectFit
                return animationView
            }
        }

        """
    }
}
