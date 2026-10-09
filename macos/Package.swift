// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DivotCore",
    platforms: [.macOS(.v26)],
    products: [.library(name: "DivotCore", targets: ["DivotCore"])],
    targets: [
        .target(name: "DivotCore"),
        .testTarget(name: "DivotCoreTests", dependencies: ["DivotCore"])
    ]
)
