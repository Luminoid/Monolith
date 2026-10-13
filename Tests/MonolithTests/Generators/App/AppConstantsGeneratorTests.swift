import Foundation
import Testing
@testable import MonolithLib

struct AppConstantsGeneratorTests {
    private func makeConfig(
        macCatalyst: Bool = false,
        tabs: [TabDefinition] = [],
        features: Set<AppFeature> = [],
        name: String = "TestApp"
    ) -> AppConfig {
        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
    }

    /// Only notifications something in the scaffold posts are declared. The
    /// memory-warning relay, the Mac-only menu broadcasts, and the routing
    /// broadcasts (deep link, Spotlight, notification tap) are gone: routing
    /// goes through the root view controller.
    @Test
    func `AppNotification declares only names the scaffold posts`() {
        let everything = makeConfig(
            macCatalyst: true,
            tabs: [TabDefinition(name: "Home", icon: "house")],
            features: [.notifications, .deepLinks, .spotlight],
            name: "MyApp"
        )
        let output = AppConstantsGenerator.generate(config: everything)
        #expect(output.contains("nonisolated enum AppNotification"))
        for removed in ["MemoryWarning", "UserNotificationReceived", "DeepLinkReceived", "SpotlightItemSelected", "MacMenuRefresh", "MacMenuSwitchTab", "DataChanged"] {
            #expect(!output.contains("\"MyApp\(removed)\""))
        }
    }

    @Test
    func `an app with nothing to post gets an example instead of names`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(name: "MyApp"))
        #expect(output.contains("""
        nonisolated enum AppNotification {
            // Add app-wide notification names here.
            // static let itemsChanged = NSNotification.Name("MyAppItemsChanged")
        }
        """))
    }

    /// The View menu exists whenever there are tabs, on every idiom.
    @Test
    func `tabs add the refresh notification`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(tabs: [TabDefinition(name: "Home", icon: "house")]))
        #expect(output.contains("    static let refreshRequested = NSNotification.Name(\"TestAppRefreshRequested\")"))
        let tabless = AppConstantsGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(!tabless.contains("refreshRequested"))
    }

    @Test
    func `Core Data sharing adds the share-requires-sync notification`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(features: [.cloudKitSharing]))
        #expect(output.contains("    static let cloudKitShareRequiresSync = NSNotification.Name(\"TestAppCloudKitShareRequiresSync\")"))
        let swiftData = AppConstantsGenerator.generate(config: makeConfig(features: [.swiftData, .cloudKit]))
        #expect(!swiftData.contains("cloudKitShareRequiresSync"))
    }

    /// A `//` comment straight above a declaration trips SwiftFormat's
    /// `docComments`; every comment above a member is a `///` doc comment.
    @Test
    func `no plain line comment sits directly above a declaration`() {
        let config = makeConfig(
            macCatalyst: true,
            tabs: [TabDefinition(name: "Home", icon: "house")],
            features: [.cloudKitSharing]
        )
        let lines = AppConstantsGenerator.generate(config: config).components(separatedBy: "\n")
        for (index, line) in lines.enumerated().dropLast() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("// "), !trimmed.hasPrefix("// MARK:") else { continue }
            let next = lines[index + 1].trimmingCharacters(in: .whitespaces)
            let isDeclaration = ["static ", "case ", "var ", "enum ", "init"].contains { next.hasPrefix($0) }
            #expect(!isDeclaration, "comment above a declaration: \(trimmed)")
        }
    }

    @Test
    func `tabs generate TabBarTag enum`() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house"),
            TabDefinition(name: "Settings", icon: "gear"),
        ]
        let output = AppConstantsGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("nonisolated enum TabBarTag: Int, CaseIterable"))
        #expect(output.contains("case home = 0"))
        #expect(output.contains("case settings = 1"))
    }

    /// One stable identifier per tab, for the View menu, state restoration,
    /// and `LMKTab`, declared once here (the raw value is only a position).
    @Test
    func `TabBarTag carries a stable identifier and its inverse`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(tabs: [TabDefinition(name: "Home", icon: "house")]))
        #expect(output.contains("""
            var identifier: String {
                String(describing: self)
            }
        """))
        #expect(output.contains("""
            init?(identifier: String) {
                guard let tag = Self.allCases.first(where: { $0.identifier == identifier }) else { return nil }
                self = tag
            }
        """))
    }

    @Test
    func `no TabBarTag without tabs`() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(!output.contains("TabBarTag"))
    }

    /// Minimum size only: a maximum would block full screen and wide tiling.
    @Test
    func `Mac Catalyst adds a minimum window size`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("enum MacWindow"))
        #expect(output.contains("static let minWidth: CGFloat = 600"))
        #expect(output.contains("static let minHeight: CGFloat = 800"))
        #expect(!output.contains("maxWidth"))
        #expect(!output.contains("maxHeight"))
    }

    /// Without LumiKit, every failure path logs through one shared logger
    /// instead of building its own `Logger(subsystem:category:)`.
    @Test
    func `apps that log without LumiKit get a shared Logger app`() {
        for features: Set<AppFeature> in [[.swiftData], [.cloudKit], [.cloudKitSharing]] {
            let output = AppConstantsGenerator.generate(config: makeConfig(features: features))
            #expect(output.contains("import Foundation\nimport os\n"))
            #expect(output.contains("""
            extension Logger {
                /// The app's log, under its bundle identifier. Failure paths log the error
                /// description as `privacy: .private`, since it can carry user data.
                static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "App")
            }
            """))
        }
        for features: Set<AppFeature> in [[], [.coreData], [.swiftData, .lumiKit], [.cloudKit, .lumiKit]] {
            let output = AppConstantsGenerator.generate(config: makeConfig(features: features))
            #expect(!output.contains("import os"))
            #expect(!output.contains("extension Logger"))
        }
    }

    @Test
    func `generates UserDefaultsKey and ReuseIdentifier`() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(output.contains("nonisolated enum UserDefaultsKey"))
        #expect(output.contains("nonisolated enum ReuseIdentifier"))
        #expect(output.contains("nonisolated enum AppConstants"))
    }

    @Test
    func `MARK sections present`() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Notifications"))
        #expect(output.contains("// MARK: - UserDefaults Keys"))
        #expect(output.contains("// MARK: - App Constants"))
    }
}
