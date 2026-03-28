import Foundation
import Testing
@testable import MonolithLib

struct InfoPlistGeneratorTests {
    @Test
    func `includes scene manifest`() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UIApplicationSceneManifest"))
        #expect(output.contains("UISceneConfigurationName"))
        #expect(output.contains("$(PRODUCT_MODULE_NAME).SceneDelegate"))
    }

    @Test
    func `includes launch screen`() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UILaunchScreen"))
    }

    @Test
    func `includes full screen and orientation settings`() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UIRequiresFullScreen"))
        #expect(output.contains("UISupportedInterfaceOrientations"))
        #expect(output.contains("UIInterfaceOrientationPortrait"))
    }

    @Test
    func `iPad supports all orientations`() {
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("UISupportedInterfaceOrientations~ipad"))
        #expect(output.contains("UIInterfaceOrientationLandscapeLeft"))
        #expect(output.contains("UIInterfaceOrientationLandscapeRight"))
        #expect(output.contains("UIInterfaceOrientationPortraitUpsideDown"))
    }
}
