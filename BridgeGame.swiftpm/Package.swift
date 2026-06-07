// swift-tools-version: 5.5
// BRIDGE APP — Built 2026-06-07
import PackageDescription

let package = Package(
    name: "BridgeGame",
    platforms: [
        .iOS("15.2")
    ],
    targets: [
        .executableTarget(
            name: "BridgeGame",
            path: "."
        )
    ]
)
