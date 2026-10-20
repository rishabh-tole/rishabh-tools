// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rishabhwm",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RishabhWMCore"),
        .executableTarget(
            name: "rishabhwm",
            dependencies: ["RishabhWMCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        // Plain executable test runner: works with Command Line Tools alone (no Xcode / XCTest).
        .executableTarget(
            name: "core-tests",
            dependencies: ["RishabhWMCore"],
            path: "Tests/core-tests"
        ),
    ]
)
