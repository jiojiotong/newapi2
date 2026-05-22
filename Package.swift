// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "NewAPIAdmin",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "NewAPIAdmin", targets: ["NewAPIAdmin"])
    ],
    targets: [
        .target(
            name: "NewAPIAdmin",
            path: "NewAPIAdmin",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "NewAPIAdminTests",
            dependencies: ["NewAPIAdmin"],
            path: "Tests/NewAPIAdminTests"
        )
    ]
)
