// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rishabhfc",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RishabhFCCore"),
        .executableTarget(
            name: "rishabhfc",
            dependencies: ["RishabhFCCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("PDFKit"),
            ]
        ),
        // Plain executable test runner: works with Command Line Tools alone (no Xcode / XCTest).
        .executableTarget(
            name: "core-tests",
            dependencies: ["RishabhFCCore"],
            path: "Tests/core-tests"
        ),
    ]
)
