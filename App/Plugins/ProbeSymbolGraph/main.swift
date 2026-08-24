import PackagePlugin

// Exercises the second code path: PackageManager.getSymbolGraph(for:options:),
// which is what swift-docc-plugin calls. Reported separately from `dump-symbol-graph`
// because they are distinct call sites in SwiftPM.
@main struct ProbeSymbolGraph: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        for target in context.package.targets where target.name == "App" {
            _ = try packageManager.getSymbolGraph(
                for: target,
                options: .init(minimumAccessLevel: .public,
                               includeSynthesized: false,
                               includeSPI: false))
        }
    }
}
