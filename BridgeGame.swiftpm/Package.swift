// swift-tools-version: 5.5
// Conventional Wisdom — modified 2026-08-14 21:29 UTC
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
            // The table is a landscape iPad layout: a fixed-width score column
            // plus West / centre / East columns and a 13-card fan. It has no
            // portrait or iPhone form, so those are not advertised.
            supportedDeviceFamilies: [
                .pad
            ],
            supportedInterfaceOrientations: [
                .landscapeLeft,
                .landscapeRight
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
