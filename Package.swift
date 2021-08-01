// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Entwine",
    platforms: [
        .macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)
    ],
    products: [
        .library(
            name: "Entwine",
            targets: ["Entwine"]),
        .library(
            name: "EntwineTest",
            targets: ["EntwineTest"]),
    ],
    targets: [
        .target(
            name: "Entwine",
            dependencies: []),
        .target(
            name: "EntwineTest",
            dependencies: ["Entwine"]),
        .testTarget(
            name: "EntwineTests",
            dependencies: ["Entwine", "EntwineTest"]),
        .testTarget(
            name: "EntwineTestTests",
            dependencies: ["EntwineTest"]),
    ]
)
