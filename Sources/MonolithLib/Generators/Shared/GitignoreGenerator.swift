enum GitignoreGenerator {
    struct Options: Sendable {
        var projectType: ProjectType = .app
        var hasRSwift: Bool = false
        var hasFastlane: Bool = false
        var appName: String?
    }

    static func generate(options: Options) -> String {
        var sections: [String] = []

        // Xcode
        var xcodeLines = ["# Xcode", "xcuserdata/", "*.hmap", "*.ipa", "*.dSYM.zip", "*.dSYM"]
        if options.projectType == .app {
            xcodeLines.append("timeline.xctimeline")
            xcodeLines.append("playground.xcworkspace")
        }
        if options.projectType == .package {
            xcodeLines.append("*.xcscmblueprint")
        }
        sections.append(xcodeLines.joined(separator: "\n"))

        // Swift Package Manager
        var spmLines = ["# Swift Package Manager", ".build/", "build/"]
        if options.projectType == .package {
            spmLines.append(".swiftpm/")
            spmLines.append("Package.resolved")
        }
        sections.append(spmLines.joined(separator: "\n"))

        sections.append("""
        # macOS
        .DS_Store
        """)

        sections.append("""
        # Claude Code
        .claude/settings.local.json
        """)

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
