// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HeroNets",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "HeroNets",
            targets: ["HeroNets"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/kyouko-taiga/AlpineLang.git", .branch("master")),
        .package(url: "https://github.com/kyouko-taiga/DDKit.git", .branch("master")),
        //.product(name: "AlpineLib", package: "AlpineLang"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "HeroNets",
            dependencies:
            [
              .product(name: "AlpineLib", package: "AlpineLang"),
              "DDKit"
            ]),
        .testTarget(
            name: "HeroNetsTests",
            dependencies: ["HeroNets"]),
    ]
)
