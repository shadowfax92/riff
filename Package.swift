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
    targets: [
        .target(name: "RiffCore"),
        .executableTarget(
            name: "RiffApp",
            dependencies: ["RiffCore"]
        ),
        .testTarget(
            name: "RiffCoreTests",
            dependencies: ["RiffCore"]
        ),
    ]
)
