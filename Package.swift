// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DocumentScanner",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DocumentScanner",
            targets: ["DocumentScanner"]
        ),
    ],
    targets: [
        .target(
            name: "DocumentScanner",
            path: "Sources/DocumentScanner",
            resources: [
                .process("Metal")
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DocumentScannerTests",
            dependencies: ["DocumentScanner"],
            path: "Tests/DocumentScannerTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
