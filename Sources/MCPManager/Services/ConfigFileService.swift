import Foundation

/// Reads and writes MCP server config files with backup support.
final class ConfigFileService: Sendable {

    private let parser = ConfigParser()
    private nonisolated(unsafe) let fm = FileManager.default

    // MARK: - Backup

    private func backupDirectory(for tool: ToolKind) -> URL {
        let home = fm.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".mcp-manager/backups/\(tool.rawValue)")
    }

    func createBackup(for tool: ToolKind) throws -> URL? {
        let configPath = tool.configFilePath
        guard fm.fileExists(atPath: configPath.path) else { return nil }

        let backupDir = backupDirectory(for: tool)
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = backupDir.appendingPathComponent("\(timestamp).json")

        // Skip if a backup for this exact timestamp already exists (same operation
        // writing to the same tool more than once in a second — treat as no-op).
        guard !fm.fileExists(atPath: backupURL.path) else { return backupURL }

        try fm.copyItem(at: configPath, to: backupURL)
        return backupURL
    }

    // MARK: - Read

    func readConfig(for tool: ToolKind) throws -> ToolConfig {
        let configPath = tool.configFilePath

        guard fm.fileExists(atPath: configPath.path) else {
            return ToolConfig(tool: tool, filePath: configPath)
        }

        let data = try Data(contentsOf: configPath)
        let servers = try parser.parseServers(from: data, tool: tool)

        let attrs = try? fm.attributesOfItem(atPath: configPath.path)
        let modified = attrs?[.modificationDate] as? Date

        return ToolConfig(
            tool: tool,
            filePath: configPath,
            servers: servers,
            lastModified: modified
        )
    }

    // MARK: - Write

    func writeConfig(_ config: ToolConfig) throws {
        let configPath = config.filePath

        // Create parent directories if needed
        let parentDir = configPath.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Create backup before writing
        _ = try createBackup(for: config.tool)

        // Read existing data to preserve unknown keys
        let existingData: Data? = fm.fileExists(atPath: configPath.path)
            ? try Data(contentsOf: configPath)
            : nil

        let data = try parser.serializeServers(
            config.servers,
            into: existingData,
            tool: config.tool
        )

        try data.write(to: configPath, options: .atomic)
    }

    // MARK: - Create

    func createConfigIfNeeded(for tool: ToolKind) throws -> URL {
        let configPath = tool.configFilePath

        if fm.fileExists(atPath: configPath.path) {
            return configPath
        }

        let parentDir = configPath.deletingLastPathComponent()
        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let emptyConfig: [String: Any] = [tool.rootKey: [:] as [String: Any]]
        let data = try JSONSerialization.data(
            withJSONObject: emptyConfig,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: configPath, options: .atomic)
        return configPath
    }

    // MARK: - Single server operations

    func addServer(_ server: MCPServer, to tool: ToolKind) throws {
        var config = try readConfig(for: tool)
        config.servers[server.name] = server
        try writeConfig(config)
    }

    func updateServer(_ server: MCPServer, in tool: ToolKind, replacingKey oldKey: String? = nil) throws {
        var config = try readConfig(for: tool)
        // If the server was renamed, remove the old entry first
        if let oldKey, oldKey != server.name {
            config.servers.removeValue(forKey: oldKey)
        }
        config.servers[server.name] = server
        try writeConfig(config)
    }

    func deleteServer(named name: String, from tool: ToolKind) throws {
        var config = try readConfig(for: tool)
        config.servers.removeValue(forKey: name)
        try writeConfig(config)
    }
}
