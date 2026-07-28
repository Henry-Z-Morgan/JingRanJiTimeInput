// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JingRanJiTimeInput",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "JingRanJiTimeInput", targets: ["JingRanJiTimeInput"])
    ],
    targets: [
        .target(name: "JingRanJiTimeInput"),
        .testTarget(name: "JingRanJiTimeInputTests", dependencies: ["JingRanJiTimeInput"])
    ]
)
