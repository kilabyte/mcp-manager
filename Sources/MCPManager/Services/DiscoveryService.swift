import Foundation

/// Scans the filesystem for installed AI tools and their MCP server configurations.
final class DiscoveryService: Sendable {

    private let configService = ConfigFileService()

    /// Returns only tools whose config file or parent directory exists.
    func discoverInstalledTools() -> [ToolKind] {
        ToolKind.allCases.filter(\.isInstalled)
    }

    /// Discovers all installed tools and loads their configurations.
    func discoverAllConfigs() -> [ToolConfig] {
        var configs: [ToolConfig] = []
        for tool in ToolKind.allCases {
            if let config = try? configService.readConfig(for: tool) {
                configs.append(config)
            }
        }
        return configs
    }
}
