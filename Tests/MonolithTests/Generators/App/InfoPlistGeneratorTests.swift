import Foundation
import Testing
@testable import MonolithLib

@Suite("InfoPlistGenerator")
struct InfoPlistGeneratorTests {
    @Test("includes scene manifest")
    func sceneManifest() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UIApplicationSceneManifest"))
        #expect(output.contains("UISceneConfigurationName"))
        #expect(output.contains("$(PRODUCT_MODULE_NAME).SceneDelegate"))
    }

    @Test("includes launch screen")
    func launchScreen() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UILaunchScreen"))
    }

    @Test("includes full screen and orientation settings")
    func orientationSettings() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UIRequiresFullScreen"))
        #expect(output.contains("UISupportedInterfaceOrientations"))
        #expect(output.contains("UIInterfaceOrientationPortrait"))
    }

    @Test("iPad supports all orientations")
    func iPadOrientations() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UISupportedInterfaceOrientations~ipad"))
        #expect(output.contains("UIInterfaceOrientationLandscapeLeft"))
        #expect(output.contains("UIInterfaceOrientationLandscapeRight"))
        #expect(output.contains("UIInterfaceOrientationPortraitUpsideDown"))
    }
}
