import Foundation

enum SPMAppGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("// swift-tools-version: 6.2")
        lines.append("")
        lines.append("import PackageDescription")
        lines.append("")
        lines.append("let package = Package(")
        lines.append("    name: \"\(config.name)\",")

        // Platforms
        var platforms: [String] = []
        platforms.append(".iOS(.v\(majorVersion(config.deploymentTarget)))")
        if config.hasMacCatalyst {
            platforms.append(".macCatalyst(.v\(majorVersion(config.deploymentTarget)))")
        }
        lines.append("    platforms: [\(platforms.joined(separator: ", "))],")

        // Dependencies
        var deps: [String] = []
        if config.hasLumiKit {
            deps.append("        .package(url: \"https://github.com/Luminoid/LumiKit.git\", from: \"0.2.0\"),")
        }
        if config.hasSnapKit {
            deps.append("        .package(url: \"https://github.com/SnapKit/SnapKit.git\", from: \"5.7.0\"),")
        }
        if config.hasLottie {
            deps.append("        .package(url: \"https://github.com/airbnb/lottie-spm.git\", from: \"4.5.0\"),")
        }

        if !deps.isEmpty {
            lines.append("    dependencies: [")
            for dep in deps {
                lines.append(dep)
            }
            lines.append("    ],")
        }

        // Targets
        lines.append("    targets: [")

        // Main executable target
        var targetDeps: [String] = []
        if config.hasLumiKit {
            targetDeps.append("            .product(name: \"LumiKitUI\", package: \"LumiKit\"),")
        }
        if config.hasSnapKit {
            targetDeps.append("            .product(name: \"SnapKit\", package: \"SnapKit\"),")
        }
        if config.hasLottie {
            targetDeps.append("            .product(name: \"Lottie\", package: \"lottie-spm\"),")
        }

        lines.append("        .executableTarget(")
        lines.append("            name: \"\(config.name)\",")
        if !targetDeps.isEmpty {
            lines.append("            dependencies: [")
            for dep in targetDeps {
                lines.append(dep)
            }
            lines.append("            ],")
        }
        lines.append("            path: \"\(config.name)\"")
        lines.append("        ),")

        // Test target
        lines.append("        .testTarget(")
        lines.append("            name: \"\(config.name)Tests\",")
        lines.append("            dependencies: [\"\(config.name)\"],")
        lines.append("            path: \"\(config.name)Tests\"")
        lines.append("        ),")

        lines.append("    ]")
        lines.append(")")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func majorVersion(_ version: String) -> String {
        String(version.split(separator: ".").first ?? "18")
    }
}
