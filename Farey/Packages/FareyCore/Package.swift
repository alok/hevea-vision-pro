// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "FareyCore", products: [.library(name: "FareyCore", targets: ["FareyCore"])], targets: [.target(name: "FareyCore"), .testTarget(name: "FareyCoreTests", dependencies: ["FareyCore"])])
