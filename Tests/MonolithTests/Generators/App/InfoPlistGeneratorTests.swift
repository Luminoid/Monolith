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
    func `emits standard bundle-metadata keys backed by build variables`() {
        // With GENERATE_INFOPLIST_FILE = NO, Xcode does NOT auto-merge the
        // standard bundle-metadata keys (CFBundleIdentifier, CFBundleVersion,
        // etc.) into the .app's binary Info.plist. The hand-written file MUST
        // declare them itself, using `$(BUILD_VARIABLE)` forms that resolve
        // from the target's build settings at build time. Without
        // CFBundleIdentifier in particular, the simulator refuses to install
        // the .app with "Missing bundle ID."
        let output = InfoPlistGenerator.generate()
        #expect(output.contains("<key>CFBundleIdentifier</key>"))
        #expect(output.contains("<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>"))
        #expect(output.contains("<key>CFBundleExecutable</key>"))
        #expect(output.contains("<string>$(EXECUTABLE_NAME)</string>"))
        #expect(output.contains("<key>CFBundleName</key>"))
        #expect(output.contains("<string>$(PRODUCT_NAME)</string>"))
        #expect(output.contains("<key>CFBundleVersion</key>"))
        #expect(output.contains("<string>$(CURRENT_PROJECT_VERSION)</string>"))
        #expect(output.contains("<key>CFBundleShortVersionString</key>"))
        #expect(output.contains("<string>$(MARKETING_VERSION)</string>"))
        #expect(output.contains("<key>CFBundleDevelopmentRegion</key>"))
        #expect(output.contains("<key>CFBundleInfoDictionaryVersion</key>"))
        #expect(output.contains("<key>LSRequiresIPhoneOS</key>"))
    }

    @Test
    func `includes orientation settings`() {
        // `UIRequiresFullScreen = true` was previously emitted by default. It
        // blocks iPad Slide Over / Split View on iPad, which is the wrong
        // default for modern apps — modern iOS apps usually omit this and
        // let the user multitask. Apps that genuinely need fullscreen
        // (camera capture, immersive games) opt back in by editing the
        // Info.plist directly.
        let output = InfoPlistGenerator.generate()
        #expect(!output.contains("UIRequiresFullScreen"))
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

    // MARK: - Optional Privacy / Capability Strings

    @Test
    func `default output omits optional usage strings`() {
        let output = InfoPlistGenerator.generate()
        #expect(!output.contains("NSPhotoLibraryUsageDescription"))
        #expect(!output.contains("NSCameraUsageDescription"))
        #expect(!output.contains("UIBackgroundModes"))
        #expect(!output.contains("CKSharingSupported"))
        #expect(!output.contains("CFBundleURLTypes"))
    }

    @Test
    func `photo library usage string is emitted when set`() {
        var options = InfoPlistGenerator.Options()
        options.photoLibraryUsageDescription = "Read photo metadata to suggest dates."
        let output = InfoPlistGenerator.generate(options: options)
        #expect(output.contains("NSPhotoLibraryUsageDescription"))
        #expect(output.contains("Read photo metadata to suggest dates."))
    }

    @Test
    func `empty usage strings are not emitted`() {
        var options = InfoPlistGenerator.Options()
        options.cameraUsageDescription = ""
        let output = InfoPlistGenerator.generate(options: options)
        #expect(!output.contains("NSCameraUsageDescription"))
    }

    @Test
    func `background modes appear as array entries`() {
        var options = InfoPlistGenerator.Options()
        options.backgroundModes = ["remote-notification", "fetch"]
        let output = InfoPlistGenerator.generate(options: options)
        #expect(output.contains("<key>UIBackgroundModes</key>"))
        #expect(output.contains("<string>remote-notification</string>"))
        #expect(output.contains("<string>fetch</string>"))
    }

    @Test
    func `CloudKit sharing flag is emitted when true`() {
        var options = InfoPlistGenerator.Options()
        options.cloudKitSharing = true
        let output = InfoPlistGenerator.generate(options: options)
        #expect(output.contains("CKSharingSupported"))
    }

    @Test
    func `URL schemes register under CFBundleURLTypes`() {
        var options = InfoPlistGenerator.Options()
        options.urlSchemes = ["myapp", "myapp-debug"]
        let output = InfoPlistGenerator.generate(options: options)
        #expect(output.contains("CFBundleURLTypes"))
        #expect(output.contains("<string>myapp</string>"))
        #expect(output.contains("<string>myapp-debug</string>"))
    }

    @Test
    func `multiple options compose without conflict`() {
        var options = InfoPlistGenerator.Options()
        options.photoLibraryUsageDescription = "Stub"
        options.backgroundModes = ["remote-notification"]
        options.cloudKitSharing = true
        options.urlSchemes = ["myapp"]
        let output = InfoPlistGenerator.generate(options: options)
        #expect(output.contains("NSPhotoLibraryUsageDescription"))
        #expect(output.contains("UIBackgroundModes"))
        #expect(output.contains("CKSharingSupported"))
        #expect(output.contains("CFBundleURLTypes"))
    }

    @Test
    func `URL types emit CFBundleURLName when urlIdentifier set`() {
        // Apple-recommended reverse-DNS identifier. Without it, system tools
        // can't disambiguate URL handler identity when multiple apps register
        // the same scheme. Generator defaults to the bundle ID.
        var options = InfoPlistGenerator.Options()
        options.urlSchemes = ["myapp"]
        options.urlIdentifier = "dev.luminoid.myapp"
        let output = InfoPlistGenerator.generate(options: options)
        #expect(output.contains("<key>CFBundleURLName</key>"))
        #expect(output.contains("<string>dev.luminoid.myapp</string>"))
    }

    @Test
    func `URL types omits CFBundleURLName when urlIdentifier is nil`() {
        var options = InfoPlistGenerator.Options()
        options.urlSchemes = ["myapp"]
        let output = InfoPlistGenerator.generate(options: options)
        #expect(!output.contains("CFBundleURLName"))
        #expect(output.contains("CFBundleURLTypes"))
    }

    @Test
    func `LSApplicationCategoryType emits when applicationCategoryType set`() {
        // LSApplicationCategoryType lives in the Info.plist (not as an
        // INFOPLIST_KEY_* build setting) so the file is self-describing.
        // Required for Mac App Store distribution.
        var options = InfoPlistGenerator.Options()
        options.applicationCategoryType = "public.app-category.productivity"
        let output = InfoPlistGenerator.generate(options: options)
        #expect(output.contains("<key>LSApplicationCategoryType</key>"))
        #expect(output.contains("<string>public.app-category.productivity</string>"))
    }

    @Test
    func `LSApplicationCategoryType omitted when applicationCategoryType nil`() {
        let output = InfoPlistGenerator.generate(options: .empty)
        #expect(!output.contains("LSApplicationCategoryType"))
    }
}
