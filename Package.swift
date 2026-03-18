// swift-tools-version: 5.9
// Package.swift — for SwiftTerm integration (v0.2.0)
// Currently ROBOTERM uses xcodegen + GhosttyKit xcframework.
// This Package.swift prepares for migrating to SwiftTerm (pure Swift).

import PackageDescription

let package = Package(
    name: "roboterm",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "roboterm", targets: ["roboterm"])
    ],
    dependencies: [
        // SwiftTerm — pure Swift terminal emulator (v0.2.0 migration target)
        // .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),

        // RosSwift — native Swift ROS2 pub/sub (future integration)
        // .package(url: "https://github.com/tgu/RosSwift.git", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "roboterm",
            dependencies: [
                // "SwiftTerm",
            ],
            path: "Sources"
        ),
    ]
)
