// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Riff",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "RiffCore", targets: ["RiffCore"]),
        .executable(name: "Riff", targets: ["RiffApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
    ],
    targets: [
        .target(name: "RiffCore"),
        .executableTarget(
            name: "RiffApp",
            dependencies: [
                "RiffCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            // MarkdownUI predates Swift 6 strict concurrency: its block-style
            // configuration closures call @MainActor-isolated modifiers and
            // trip ActorIsolatedCall errors in Swift 6 mode. The library is
            // fine at runtime — UI code already runs on the main actor — so
            // we keep RiffCore on Swift 6 and drop RiffApp to v5.
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "RiffCoreTests",
            dependencies: ["RiffCore"]
        ),
    ]
)
