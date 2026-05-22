// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "NewAPIAdmin",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "NewAPIAdmin", targets: ["NewAPIAdmin"]),
        .executable(name: "NewAPIAdminApp", targets: ["NewAPIAdminApp"])
    ],
    targets: [
        .target(
            name: "NewAPIAdmin",
            path: "NewAPIAdmin",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "NewAPIAdminApp",
            dependencies: ["NewAPIAdmin"],
            path: "NewAPIAdminApp"
        ),
        .testTarget(
            name: "NewAPIAdminTests",
            dependencies: ["NewAPIAdmin"],
            path: "Tests/NewAPIAdminTests"
        )
    ]
)
