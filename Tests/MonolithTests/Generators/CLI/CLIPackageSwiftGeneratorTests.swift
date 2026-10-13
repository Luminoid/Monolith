import Foundation
import Testing
@testable import MonolithLib

struct CLIPackageSwiftGeneratorTests {
    private func manifest(_ name: String, argumentParser: Bool = true) -> String {
        CLIPackageSwiftGenerator.generate(config: CLIConfig(
            name: name,
            includeArgumentParser: argumentParser,
            features: [],
            author: "Test",
            licenseType: .apache2
        ))
    }

    @Test
    func `tools version comes from ToolVersion`() {
        #expect(manifest("my-tool").hasPrefix("// swift-tools-version: \(ToolVersion.swift)\n"))
    }

    @Test
    func `declares a library, a thin executable, and a library test target`() {
        let output = manifest("my-tool")
        // Exact line sequence: library holds ArgumentParser, the executable
        // depends only on the library, tests depend on the library.
        #expect(output.contains("""
            products: [
                .executable(name: "my-tool", targets: ["my-tool"]),
            ],
        """))
        #expect(output.contains("""
                .target(
                    name: "MyToolKit",
                    dependencies: [
                        .product(name: "ArgumentParser", package: "swift-argument-parser"),
                    ]
                ),
                .executableTarget(
                    name: "my-tool",
                    dependencies: ["MyToolKit"]
                ),
                .testTarget(
                    name: "MyToolKitTests",
                    dependencies: ["MyToolKit"]
                ),
        """))
        #expect(!output.contains("my-toolTests"))
    }

    @Test
    func `plain CLI has no ArgumentParser dependency`() {
        let output = manifest("ToolX", argumentParser: false)
        #expect(!output.contains("ArgumentParser"))
        #expect(!output.contains("swift-argument-parser"))
        #expect(output.contains("""
                .target(
                    name: "ToolXKit",
                    dependencies: []
                ),
        """))
        #expect(output.contains("name: \"ToolX\","))
    }
}
