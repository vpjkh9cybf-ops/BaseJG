// swift-tools-version: 5.5
// BRIDGE APP — Built 2026-06-07
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "BridgeGame",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "BridgeGame",
            targets: ["BridgeGame"],
            bundleIdentifier: "com.bridge.game",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "BridgeGame",
            path: "."
        )
    ]
)
