// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NewAPIAdmin",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
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
