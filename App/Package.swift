// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "App",
    platforms: [.macOS(.v13)],
    products: [.library(name: "App", targets: ["App"])],
    traits: [
        // Declared but NOT listed as a default trait, so it is disabled unless
        // the consumer opts in with `--traits Heavy`.
        .trait(name: "Heavy", description: "Pulls in a large binary artifact."),
    ],
    dependencies: [.package(path: "../BinaryDep")],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "BinWrap", package: "BinaryDep",
                     condition: .when(traits: ["Heavy"]))
        ]),
        .plugin(name: "ProbeSymbolGraph", capability: .command(
            intent: .custom(verb: "probe-symbol-graph",
                            description: "Requests a symbol graph via the plugin API."))),
        .plugin(name: "ProbeBuild", capability: .command(
            intent: .custom(verb: "probe-build",
                            description: "Negative control: requests a build via the plugin API."))),
    ])
