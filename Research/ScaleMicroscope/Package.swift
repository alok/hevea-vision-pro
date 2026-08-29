// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HeveaScaleMicroscope",
    products: [
        .executable(
            name: "hevea-scale-microscope",
            targets: ["HeveaScaleMicroscopeCLI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/HeveaCore"),
    ],
    targets: [
        .target(
            name: "ScaleMicroscopeExperiment",
            dependencies: [
                .product(name: "HeveaCore", package: "HeveaCore"),
            ]
        ),
        .executableTarget(
            name: "HeveaScaleMicroscopeCLI",
            dependencies: ["ScaleMicroscopeExperiment"]
        ),
        .testTarget(
            name: "ScaleMicroscopeExperimentTests",
            dependencies: ["ScaleMicroscopeExperiment"]
        ),
    ]
)
