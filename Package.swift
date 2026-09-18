// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Perde",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Perde",
            path: "Sources/Perde"
        ),
        .testTarget(
            name: "PerdeTests",
            dependencies: ["Perde"],
            path: "Tests/PerdeTests"
        )
    ]
)
