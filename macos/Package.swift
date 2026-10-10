// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DivotCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DivotCore", targets: ["DivotCore"]),
        .library(name: "DivotAppKit", targets: ["DivotAppKit"]),
        .executable(name: "divot", targets: ["DivotApp"]),
        .executable(name: "divot-menu-bar-probe", targets: ["DivotMenuBarProbe"]),
        .executable(name: "divot-spaces-probe", targets: ["DivotSpacesProbe"])
    ],
    targets: [
        .target(name: "DivotCore"),
        .target(name: "DivotAppKit", dependencies: ["DivotCore"],
                resources: [.process("Resources")]),
        .executableTarget(name: "DivotApp", dependencies: ["DivotCore", "DivotAppKit"]),
        .executableTarget(name: "DivotMenuBarProbe", dependencies: ["DivotCore", "DivotAppKit"]),
        .executableTarget(name: "DivotSpacesProbe", dependencies: ["DivotCore"]),
        .testTarget(name: "DivotCoreTests", dependencies: ["DivotCore"]),
        .testTarget(name: "DivotAppKitTests", dependencies: ["DivotAppKit"])
    ]
)
