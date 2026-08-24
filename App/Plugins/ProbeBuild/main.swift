import PackagePlugin

// Negative control. Same plugin API, same disabled trait, but asks for a BUILD
// rather than a symbol graph. This one behaves correctly: no download is attempted.
@main struct ProbeBuild: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        _ = try packageManager.build(.all(includingTests: false),
                                     parameters: .init(configuration: .debug))
    }
}
