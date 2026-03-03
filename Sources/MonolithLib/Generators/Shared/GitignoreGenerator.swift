enum GitignoreGenerator {
    struct Options: Sendable {
        var projectType: ProjectType = .app
        var hasRSwift: Bool = false
        var hasFastlane: Bool = false
        var appName: String?
    }

    static func generate(options: Options) -> String {
        var sections: [String] = []

        // Base (all project types)
        sections.append("""
        # Xcode
        xcuserdata/
        *.hmap
        *.ipa
        *.dSYM.zip
        *.dSYM
        """)

        sections.append("""
        # Swift Package Manager
        .build/
        build/
        """)

        sections.append("""
        # macOS
        .DS_Store
        """)

        sections.append("""
        # Claude Code
        .claude/settings.local.json
        """)

        // iOS App additions
        if options.projectType == .app {
            sections.append("""
            # Xcode specifics
            timeline.xctimeline
            playground.xcworkspace
            """)
        }

        // Swift Package additions
        if options.projectType == .package {
            sections.append("""
            # Swift Package Manager
            .swiftpm/

            # Xcode
            *.xcscmblueprint
            """)
        }

        // R.swift (iOS app only)
        if options.hasRSwift, let appName = options.appName {
            sections.append("""
            # R.swift generated
            \(appName)/Generated/R.generated.swift
            """)
        }

        // Fastlane
        if options.hasFastlane {
            sections.append("""
            # Fastlane
            fastlane/report.xml
            fastlane/Preview.html
            fastlane/screenshots/**/*.png
            fastlane/test_output

            # Bundler
            vendor/bundle/
            """)
        }

        return sections.joined(separator: "\n\n") + "\n"
    }
}
