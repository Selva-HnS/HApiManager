// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HApiManager",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "HApiManager",
            targets: ["HApiManager"]),
    ],
    dependencies: [
        // Add your SPM dependency here
        .package(url: "https://github.com/Selva-HnS/SSLPinningManager.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "HApiManager",
            dependencies: [.product(name: "SSLPinningManager", package: "SSLPinningManager")]),
//        .binaryTarget(
//            name: "SSLPinningManager",
//            path: "./Sources/SSLPinningManager.xcframework"
//        ),
        .testTarget(
            name: "HApiManagerTests",
            dependencies: ["HApiManager"]
        ),
    ]
)
