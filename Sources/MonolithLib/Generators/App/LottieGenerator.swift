/// Generates Lottie-related code and dependency configuration.
enum LottieGenerator {
    /// Generate a sample Lottie animation view helper. Looping animations play
    /// once under Reduce Motion, and playback pauses in the background and
    /// resumes when the app returns.
    static func generateHelper() -> String {
        """
        import Lottie
        import UIKit

        /// Helper for creating Lottie animation views (main actor: they are UIKit views).
        @MainActor
        enum LottieHelper {
            /// Create an animation view for a bundled animation file.
            ///
            /// With Reduce Motion on, the animation plays once instead of looping.
            /// The setting is read when the view is made, so a view that should
            /// follow later changes observes
            /// `UIAccessibility.reduceMotionStatusDidChangeNotification`.
            static func makeAnimationView(
                named name: String,
                loopMode: LottieLoopMode = .loop
            ) -> LottieAnimationView {
                let animationView = LottieAnimationView(name: name)
                animationView.loopMode = UIAccessibility.isReduceMotionEnabled ? .playOnce : loopMode
                animationView.backgroundBehavior = .pauseAndRestore
                animationView.contentMode = .scaleAspectFit
                return animationView
            }
        }

        """
    }
}
