// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BinaryDep",
    products: [.library(name: "BinWrap", targets: ["BinWrap"])],
    targets: [
        // The URL is deliberately unreachable and the checksum is bogus.
        // Nothing is ever downloaded: the *attempt* is the symptom we are detecting.
        .binaryTarget(
            name: "Bin",
            url: "https://example.invalid/Bin.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"),
        .target(name: "BinWrap", dependencies: ["Bin"]),
    ])
