// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CleanYourMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CleanYourMac",
            targets: ["CleanYourMac"]
        )
    ],
    dependencies: [
        // No external dependencies for now
    ],
    targets: [
        .executableTarget(
            name: "CleanYourMac",
            dependencies: [],
            resources: [
                .process("Resources")
            ])
    ]
)
