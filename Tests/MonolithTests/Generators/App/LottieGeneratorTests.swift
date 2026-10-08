import Foundation
import Testing
@testable import MonolithLib

struct LottieGeneratorTests {
    @Test
    func `helper is a main-actor enum that imports Lottie`() {
        let output = LottieGenerator.generateHelper()
        #expect(output.contains("import Lottie\nimport UIKit"))
        #expect(output.contains("@MainActor\nenum LottieHelper {"))
    }

    @Test
    func `looping animations play once under Reduce Motion`() {
        let output = LottieGenerator.generateHelper()
        #expect(output.contains("animationView.loopMode = UIAccessibility.isReduceMotionEnabled ? .playOnce : loopMode"))
        #expect(!output.contains("animationView.loopMode = loopMode\n"))
    }

    @Test
    func `playback pauses in the background and resumes after`() {
        let output = LottieGenerator.generateHelper()
        #expect(output.contains("animationView.backgroundBehavior = .pauseAndRestore"))
    }
}
