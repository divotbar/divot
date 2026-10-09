// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DivotCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DivotCore", targets: ["DivotCore"]),
        .executable(name: "divot-menu-bar-probe", targets: ["DivotMenuBarProbe"])
    ],
    targets: [
        .target(name: "DivotCore"),
        .executableTarget(name: "DivotMenuBarProbe", dependencies: ["DivotCore"]),
        .testTarget(name: "DivotCoreTests", dependencies: ["DivotCore"])
    ]
)
