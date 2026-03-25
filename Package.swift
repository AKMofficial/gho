// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Gho",
    platforms: [.macOS(.v14)],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "GhosttyKit",
            path: "Frameworks/GhosttyKit.xcframework"
        ),
        .executableTarget(
            name: "Gho",
            dependencies: ["GhosttyKit"],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
            ]
        ),
    ]
)
