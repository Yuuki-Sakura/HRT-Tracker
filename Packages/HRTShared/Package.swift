// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HRTShared",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "HRTModels", targets: ["HRTModels"]),
        .library(name: "HRTPKEngine", targets: ["HRTPKEngine"]),
        .library(name: "HRTServices", targets: ["HRTServices"]),
    ],
    targets: [
        .target(
            name: "HRTModels",
            path: "Sources/HRTModels"
        ),
        .target(
            name: "HRTPKEngine",
            dependencies: ["HRTModels"],
            path: "Sources/HRTPKEngine"
        ),
        .target(
            name: "HRTServices",
            dependencies: ["HRTModels"],
            path: "Sources/HRTServices"
        ),
        .testTarget(
            name: "HRTModelsTests",
            dependencies: ["HRTModels"],
            path: "Tests/HRTModelsTests"
        ),
        .testTarget(
            name: "HRTPKEngineTests",
            dependencies: ["HRTPKEngine", "HRTModels"],
            path: "Tests/HRTPKEngineTests"
        ),
        .testTarget(
            name: "HRTServicesTests",
            dependencies: ["HRTServices", "HRTModels"],
            path: "Tests/HRTServicesTests"
        ),
    ]
)
