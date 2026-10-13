import Foundation

/// Generates the app's `AppDelegate.swift`.
///
/// The generated delegate is feature-driven: SwiftData, Core Data, CloudKit
/// remote notifications, `UNUserNotificationCenterDelegate`, and the View
/// menu are each emitted only when the corresponding feature flag is set. The
/// three-phase launch comment structure (Core Infrastructure / System
/// Services / Configuration) is a guide for adopters extending the delegate.
/// Deferred post-launch work belongs to the scene (`deferredLaunchWork`),
/// which runs it once per process after the first frames.
enum AppDelegateGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append(contentsOf: imports(config: config))
        lines.append("")

        // Class declaration + base conformance
        var conformances = ["UIResponder", "UIApplicationDelegate"]
        if config.hasNotifications {
            conformances.append("UNUserNotificationCenterDelegate")
        }
        lines.append("@main")
        // `final` satisfies SwiftFormat's `preferFinalClasses`; subclassing
        // AppDelegate isn't needed for any pattern Monolith supports today.
        lines.append("final class AppDelegate: \(conformances.joined(separator: ", ")) {")

        if config.hasSwiftData {
            lines.append(contentsOf: swiftDataProperties(config: config))
        }

        lines.addMark("Application Lifecycle")
        lines.append(contentsOf: didFinishLaunching(config: config))

        lines.addMark("Scene Configuration")
        lines.append("""
            func application(
                _ application: UIApplication,
                configurationForConnecting connectingSceneSession: UISceneSession,
                options: UIScene.ConnectionOptions
            ) -> UISceneConfiguration {
                UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
            }
        """)

        // Remote notifications (CloudKit silent push)
        if config.hasCloudKitNotifications {
            lines.addMark("Remote Notifications")
            lines.append("""
                func application(
                    _ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
                ) {
                    // CloudKit silent pushes don't need the token; this delegate just confirms registration.
                }

                func application(
                    _ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: any Error
                ) {
                    \(logError("Remote notification registration failed", category: .network, config: config))
                }
            """)
        }

        if config.hasNotifications {
            lines.addMark("User Notifications")
            lines.append(userNotificationHandlers)
        }

        if config.hasLumiKit {
            lines.addMark("LumiKit Configuration")
            // The theme is a value declared in `<Name>Theme.swift`
            // (`extension LMKTheme { static let <name> }`); applying it
            // re-renders every window, so later switches use the same call.
            lines.append("    private func configureLumiKit() {")
            lines.append("        LMKTheme.apply(.\(ThemeGenerator.themeMemberName(for: config)))")
            lines.append("    }")
        }

        if config.hasSwiftData {
            lines.addMark("SwiftData")
            lines.append(createModelContainer(config: config))
        }

        if config.hasTabs {
            lines.addMark("Menu")
            lines.append(contentsOf: menu(config: config))
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Sections

    /// The import lines, sorted the way SwiftFormat's case-insensitive `sortImports` orders them.
    private static func imports(config: AppConfig) -> [String] {
        var imports: [String] = []
        if config.hasCoreData {
            imports.append("import CoreData")
        }
        if config.hasLumiKit {
            // LumiKitCore carries `LMKLogger` (used on the failure paths below,
            // and an option for adopters to reach for elsewhere).
            // `LumiKitUI` depends on `LumiKitCore` but does NOT re-export it,
            // so the explicit import is required at any call site.
            imports.append("import LumiKitCore")
            imports.append("import LumiKitUI")
        } else if config.hasSwiftData || config.hasCloudKitNotifications {
            // `Logger.app` (declared in AppConstants) for the same failure
            // paths when LumiKit is absent; naming `Logger` needs the import.
            imports.append("import os")
        }
        if config.hasSwiftData {
            imports.append("import SwiftData")
        }
        imports.append("import UIKit")
        if config.hasNotifications {
            imports.append("import UserNotifications")
        }
        return imports
    }

    /// The SwiftData container property, plus the CloudKit opt-in when the app syncs.
    ///
    /// The container is a non-optional lazy property: `createModelContainer()`
    /// is its only writer and `fatalError`s when even a local store fails, so
    /// no caller ever sees a missing container.
    private static func swiftDataProperties(config: AppConfig) -> [String] {
        var lines: [String] = []
        lines.addMark("Properties")
        if config.hasCloudKit {
            lines.append("""
                /// Whether this launch's container syncs with CloudKit, set when `modelContainer` is
                /// built: the preference, except in app-hosted test runs and a launch whose CloudKit
                /// container failed to load.
                private(set) var isCloudKitEnabled = false

            """)
        }
        lines.append("""
            /// The app's SwiftData container, built on first use (launch builds it in phase 1).
            private(set) lazy var modelContainer: ModelContainer = createModelContainer()
        """)
        if config.hasCloudKit {
            lines.addMark("Constants")
            lines.append("""
                /// UserDefaults key gating CloudKit sync. Sync is opt-in: the scaffold ships with it
                /// off so the app launches (and `make test` passes) without a CloudKit entitlement or
                /// a signed-in iCloud account. Flip it from a Settings toggle, then call `exit(0)`:
                /// a `ModelContainer` can't switch CloudKit on or off at runtime.
                static let cloudKitEnabledKey = "cloudKitSyncEnabled"
            """)
        }
        return lines
    }

    /// `application(_:didFinishLaunchingWithOptions:)`, in three commented phases.
    private static func didFinishLaunching(config: AppConfig) -> [String] {
        var lines: [String] = []
        lines.append("""
            func application(
                _ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
            ) -> Bool {
        """)

        var infrastructure: [String] = []
        if config.hasLumiKit {
            infrastructure.append("configureLumiKit()")
        }
        if config.hasSwiftData {
            infrastructure.append("_ = modelContainer")
        }
        if config.hasCoreData {
            infrastructure.append("_ = \(config.name)CoreDataStack.shared")
        }
        lines.append("        // Phase 1: Core Infrastructure")
        lines.append(contentsOf: phaseBody(infrastructure, placeholder: "Persistence and design-system setup go here"))
        lines.append("")

        var services: [String] = []
        if config.hasNotifications {
            services.append("UNUserNotificationCenter.current().delegate = self")
        }
        if config.hasCloudKitNotifications {
            // Silent pushes matter only while sync is on, which phase 1 settled.
            // Sync ships off, and registering anyway fails in every unsigned
            // build (no `aps-environment` entitlement), logging an error on each
            // launch and app-hosted test run.
            let isSyncing = config.hasSwiftData ? "isCloudKitEnabled" : "\(config.name)CoreDataStack.shared.isCloudKitEnabled"
            services.append(contentsOf: [
                "// CloudKit's silent pushes, needed only while sync is on.",
                "if \(isSyncing) {",
                "    application.registerForRemoteNotifications()",
                "}",
            ])
        }
        lines.append("        // Phase 2: System Services")
        lines.append(contentsOf: phaseBody(services, placeholder: "Notification delegates and background tasks go here"))
        lines.append("")

        // With no statement before it, `return true` is the body's only
        // expression, which SwiftFormat's `redundantReturn` and SwiftLint's
        // `implicit_return` both reject; the generated config enables both.
        let result = infrastructure.isEmpty && services.isEmpty ? "true" : "return true"
        lines.append("""
                // Phase 3: Configuration
                // Add migration or cache setup here

                \(result)
            }
        """)
        return lines
    }

    /// A launch phase's statements, or a comment saying what belongs there.
    private static func phaseBody(_ statements: [String], placeholder: String) -> [String] {
        guard !statements.isEmpty else { return ["        // \(placeholder)"] }
        return statements.map { "        \($0)" }
    }

    /// The `UNUserNotificationCenterDelegate` methods. A tap goes to the scene,
    /// which routes it through the root view controller once the UI is up: a
    /// tap that launches the app arrives before any screen exists, so a
    /// broadcast here would reach no observer.
    private static let userNotificationHandlers = """
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            // Show banner + list + sound when the app is foreground; default is to suppress.
            completionHandler([.banner, .list, .sound])
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            // The scene routes the tap through its root view controller, holding it until the
            // UI is up when the tap launched the app.
            let scene = response.targetScene ?? UIApplication.shared.connectedScenes.first
            (scene?.delegate as? SceneDelegate)?.handleNotificationResponse(response)
            completionHandler()
        }
    """

    /// `createModelContainer()`. Every configuration names its store location
    /// (`groupContainer`) and CloudKit database explicitly: `.automatic` would
    /// move the store into an App Group container as soon as the app gains one
    /// and would sync whenever the iCloud entitlement is present. Every
    /// container is built through `makeContainer(schema:configuration:)`, which
    /// creates the store's folder first.
    private static func createModelContainer(config: AppConfig) -> String {
        createContainerBody(config: config) + "\n\n" + makeContainer
    }

    /// `makeContainer(schema:configuration:)`. The store's folder (Application
    /// Support, or the same folder inside the App Group container) doesn't exist
    /// in a fresh install; SwiftData creates it after Core Data has logged a
    /// screenful of "Failed to stat path" errors on every first launch.
    private static let makeContainer = """
        /// Builds a container for `configuration`, creating the store's folder first: it
        /// doesn't exist in a fresh install, where SwiftData would log a page of Core Data
        /// errors before creating it.
        private func makeContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
            try? FileManager.default.createDirectory(at: configuration.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    """

    /// `createModelContainer()` itself.
    private static func createContainerBody(config: AppConfig) -> String {
        // A widget app keeps its store in the App Group container the widget
        // reads; every other app keeps the default location.
        let groupContainer = config.hasWidget ? ".identifier(AppGroup.identifier)" : ".none"
        let localFailure = logError("Failed to create ModelContainer", category: .data, config: config)
        guard config.hasCloudKit else {
            return """
                /// Builds the container from `AppSchema.models`. A load failure is fatal: a
                /// logged-and-ignored container leaves every later persistence call failing far from
                /// the cause, so the crash report should carry the real error.
                private func createModelContainer() -> ModelContainer {
                    do {
                        let schema = Schema(AppSchema.models)
                        let configuration = ModelConfiguration(schema: schema, groupContainer: \(groupContainer), cloudKitDatabase: .none)
                        return try makeContainer(schema: schema, configuration: configuration)
                    } catch {
                        \(localFailure)
                        fatalError("Unresolved ModelContainer error: \\(error)")
                    }
                }
            """
        }
        let cloudKitFailure = logError("CloudKit ModelContainer failed to load; running local-only this launch", category: .data, config: config)
        return """
            /// Builds the container from `AppSchema.models`. CloudKit sync is opt-in (see
            /// `cloudKitEnabledKey`) and never on in an app-hosted test run, where an unsigned host
            /// has no CloudKit entitlement and a signed one would mirror test data into iCloud.
            /// A CloudKit container that fails to load is logged and replaced by a local one for
            /// this launch, so a sync problem can't crash-loop the app before the user reaches
            /// the sync setting; the preference stays on, so the next launch retries. A local
            /// load failure is fatal: a logged-and-ignored container leaves every later
            /// persistence call failing far from the cause.
            private func createModelContainer() -> ModelContainer {
                let schema = Schema(AppSchema.models)
                let wantsCloudKit = UserDefaults.standard.bool(forKey: Self.cloudKitEnabledKey)
                    && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
                if wantsCloudKit {
                    do {
                        let configuration = ModelConfiguration(
                            schema: schema,
                            groupContainer: \(groupContainer),
                            cloudKitDatabase: .private("iCloud.\(config.bundleID)")
                        )
                        let container = try makeContainer(schema: schema, configuration: configuration)
                        isCloudKitEnabled = true
                        return container
                    } catch {
                        \(cloudKitFailure)
                    }
                }
                do {
                    let configuration = ModelConfiguration(schema: schema, groupContainer: \(groupContainer), cloudKitDatabase: .none)
                    return try makeContainer(schema: schema, configuration: configuration)
                } catch {
                    \(localFailure)
                    fatalError("Unresolved ModelContainer error: \\(error)")
                }
            }
        """
    }

    // MARK: - Failure Logging

    /// The `LMKLogger` category a generated failure line uses.
    enum LogCategory: String {
        case data
        case network
    }

    /// One generated statement that logs `error` at error level: `LMKLogger`
    /// when LumiKit is wired, else the shared `Logger.app` (declared in
    /// AppConstants) with the error description marked private (it can carry
    /// user data). With `includesError: false` the line has no error attached.
    static func logError(_ message: String, category: LogCategory, config: AppConfig, includesError: Bool = true) -> String {
        if config.hasLumiKit {
            let errorArgument = includesError ? ", error: error" : ""
            return "LMKLogger.error(\"\(message)\"\(errorArgument), category: LMKLogger.LogCategory.\(category.rawValue))"
        }
        let text = includesError ? "\(message): \\(String(describing: error), privacy: .private)" : message
        return "Logger.app.error(\"\(text)\")"
    }

    // MARK: - Menu

    /// The View menu's Refresh title: catalog key, English text, and translator
    /// comment. The menu reads it inline with `String(localized:defaultValue:comment:)`;
    /// `LocalizationGenerator` writes the same entry into the catalog of a
    /// localized app with tabs, so the two never drift.
    static let refreshCommandTitle = (key: "menu.refresh", value: "Refresh", comment: "View menu command that reloads the current screen")

    /// `buildMenu(with:)`: View menu commands for the tabs (⌘1…⌘9) and a
    /// Refresh (⌘R), on every idiom. On the Mac and the iPadOS 26 menu bar
    /// they are menu items; elsewhere they are keyboard shortcuts. Each command
    /// names a `MainTabBarController` action and travels the responder chain,
    /// so the controller can disable it under a sheet and check the selected
    /// tab. A tab-less app gets no menu: its only command would be Refresh,
    /// and the sample screen has nothing to reload; add a `buildMenu(with:)`
    /// override routed the same way once a screen has a command.
    private static func menu(config: AppConfig) -> [String] {
        var lines: [String] = []
        lines.append("""
            /// The View menu: one command per tab (⌘1…⌘\(min(config.tabs.count, 9))) and Refresh (⌘R). They are menu bar
            /// items on the Mac and iPad and keyboard shortcuts everywhere; each travels the
            /// responder chain to `MainTabBarController`, which disables them under a sheet.
            override func buildMenu(with builder: any UIMenuBuilder) {
                super.buildMenu(with: builder)
                guard builder.system == .main else { return }

                let tabs: [(title: String, tag: TabBarTag)] = [
        """)
        for tab in config.tabs.prefix(9) {
            let caseName = AppConstantsGenerator.caseName(for: tab)
            // Localized apps read the titles from the catalog, like the tab bar.
            let title = config.hasLocalization ? "L10n.Tab.\(caseName)" : "\"\(tab.name)\""
            lines.append("            (\(title), .\(caseName)),")
        }
        // The Refresh title reads the catalog key with an English default, so
        // it resolves whether or not the catalog has the key yet.
        let refresh = refreshCommandTitle
        let refreshTitle = config.hasLocalization
            ? "String(localized: \"\(refresh.key)\", defaultValue: \"\(refresh.value)\", comment: \"\(refresh.comment)\")"
            : "\"\(refresh.value)\""
        lines.append("""
                ]
                let tabCommands = tabs.enumerated().map { index, tab in
                    UIKeyCommand(
                        title: tab.title,
                        action: #selector(MainTabBarController.selectTabFromMenu(_:)),
                        input: String(index + 1),
                        modifierFlags: .command,
                        propertyList: tab.tag.identifier
                    )
                }
                let refreshCommand = UIKeyCommand(
                    title: \(refreshTitle),
                    action: #selector(MainTabBarController.refreshFromMenu(_:)),
                    input: "r",
                    modifierFlags: .command
                )
                builder.insertChild(UIMenu(options: .displayInline, children: tabCommands + [refreshCommand]), atEndOfMenu: .view)
            }
        """)
        return lines
    }
}
