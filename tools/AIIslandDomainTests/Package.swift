// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIIslandDomain",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AIIslandDomain", targets: ["AIIslandDomain"])
    ],
    targets: [
        .target(name: "AIIslandDomain"),
        .testTarget(name: "AIIslandDomainTests", dependencies: ["AIIslandDomain"])
    ]
)
