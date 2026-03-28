import Foundation

/// Defines a master/replica sync relationship for a specific MCP server.
struct SyncProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var serverName: String
    var masterTool: ToolKind
    var replicaTools: [ToolKind]

    init(
        id: UUID = UUID(),
        serverName: String,
        masterTool: ToolKind,
        replicaTools: [ToolKind] = []
    ) {
        self.id = id
        self.serverName = serverName
        self.masterTool = masterTool
        self.replicaTools = replicaTools
    }
}

/// Container for persisting all sync profiles to disk.
struct SyncProfileStore: Codable {
    var profiles: [SyncProfile]

    init(profiles: [SyncProfile] = []) {
        self.profiles = profiles
    }

    static let filePath: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".mcp-manager/sync-profiles.json")
    }()
}
