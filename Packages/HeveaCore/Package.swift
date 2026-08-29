// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HeveaCore",
    products: [
        .library(name: "HeveaCore", targets: ["HeveaCore"]),
    ],
    targets: [
        .target(name: "HeveaCore"),
        .testTarget(name: "HeveaCoreTests", dependencies: ["HeveaCore"]),
    ]
)
