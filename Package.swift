// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Monolith",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "MonolithLib", targets: ["MonolithLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "MonolithLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),
        .executableTarget(
            name: "monolith",
            dependencies: ["MonolithLib"],
        ),
        .testTarget(
            name: "MonolithTests",
            dependencies: ["MonolithLib"],
        ),
    ],
)
