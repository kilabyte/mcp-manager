import Foundation

/// Manages master/replica sync profiles and propagates changes.
final class SyncService: Sendable {

    private let configService = ConfigFileService()

    // MARK: - Profile Persistence

    func loadProfiles() throws -> [SyncProfile] {
        let path = SyncProfileStore.filePath
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        let data = try Data(contentsOf: path)
        let store = try JSONDecoder().decode(SyncProfileStore.self, from: data)
        return store.profiles
    }

    func saveProfiles(_ profiles: [SyncProfile]) throws {
        let path = SyncProfileStore.filePath
        let parentDir = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let store = SyncProfileStore(profiles: profiles)
        let data = try JSONEncoder().encode(store)

        // Pretty print for human readability
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try pretty.write(to: path, options: .atomic)
        } else {
            try data.write(to: path, options: .atomic)
        }
    }

    // MARK: - Sync Operations

    /// Propagate a server from the master tool to all replica tools.
    func syncServer(named name: String, profile: SyncProfile) throws {
        let masterConfig = try configService.readConfig(for: profile.masterTool)
        guard let server = masterConfig.servers[name] else { return }

        for replicaTool in profile.replicaTools {
            try configService.addServer(server, to: replicaTool)
        }
    }

    /// Propagate all servers that have sync profiles from their master to replicas.
    func syncAll(profiles: [SyncProfile]) throws {
        for profile in profiles {
            try syncServer(named: profile.serverName, profile: profile)
        }
    }

    /// Find the sync profile for a given server name, if any.
    func profile(for serverName: String, in profiles: [SyncProfile]) -> SyncProfile? {
        profiles.first { $0.serverName == serverName }
    }

    /// Check if a tool is a replica for a given server.
    func isReplica(tool: ToolKind, serverName: String, profiles: [SyncProfile]) -> Bool {
        guard let profile = profile(for: serverName, in: profiles) else { return false }
        return profile.replicaTools.contains(tool)
    }

    /// Check if a tool is the master for a given server.
    func isMaster(tool: ToolKind, serverName: String, profiles: [SyncProfile]) -> Bool {
        guard let profile = profile(for: serverName, in: profiles) else { return false }
        return profile.masterTool == tool
    }
}
