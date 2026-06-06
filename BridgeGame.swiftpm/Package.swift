// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BridgeGame",
    platforms: [.iOS("16.0")],
    targets: [
        .executableTarget(
            name: "BridgeGame",
            path: "Sources/BridgeGame"
        )
    ]
)
