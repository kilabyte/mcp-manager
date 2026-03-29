import Foundation
import Observation
import SwiftUI

/// Unified server representation that tracks which tools contain it.
struct UnifiedServer: Identifiable, Hashable {
    let id: String // server name as unique key
    let name: String
    var server: MCPServer
    var presentIn: Set<ToolKind>

    static func == (lhs: UnifiedServer, rhs: UnifiedServer) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Sidebar selection state.
enum SidebarSelection: Hashable {
    case allServers
    case tool(ToolKind)
    case keychain
}

@Observable
@MainActor
final class AppViewModel {

    // MARK: - State

    var toolConfigs: [ToolConfig] = []
    var syncProfiles: [SyncProfile] = []
    var sidebarSelection: SidebarSelection = .allServers
    var selectedServerName: String?
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var showAddServerSheet: Bool = false
    var showInspector: Bool = false

    // Keychain (macOS Keychain via KeychainService)
    var valsEntries: [ValsEntry] = []

    // MARK: - Services

    private let configService = ConfigFileService()
    private let discoveryService = DiscoveryService()
    private let syncService = SyncService()
    private let keychainService = KeychainService()
    private let valsService = ValsFileService()   // kept for one-time migration only
    let fileWatcher = FileWatcherService()

    // MARK: - Computed

    var installedTools: [ToolKind] {
        toolConfigs.map(\.tool)
    }

    /// All servers deduplicated by name, tracking which tools contain each.
    var unifiedServers: [UnifiedServer] {
        var map: [String: UnifiedServer] = [:]
        for config in toolConfigs {
            for (name, server) in config.servers {
                if var existing = map[name] {
                    existing.presentIn.insert(config.tool)
                    map[name] = existing
                } else {
                    map[name] = UnifiedServer(
                        id: name,
                        name: name,
                        server: server,
                        presentIn: [config.tool]
                    )
                }
            }
        }
        return map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Servers filtered by sidebar selection and search text.
    var displayedServers: [UnifiedServer] {
        var servers: [UnifiedServer]

        switch sidebarSelection {
        case .allServers:
            servers = unifiedServers
        case .tool(let tool):
            servers = unifiedServers.filter { $0.presentIn.contains(tool) }
        case .keychain:
            servers = []
        }

        if !searchText.isEmpty {
            servers = servers.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText)
                || server.server.command.localizedCaseInsensitiveContains(searchText)
            }
        }

        return servers
    }

    /// Currently selected unified server.
    var selectedServer: UnifiedServer? {
        guard let name = selectedServerName else { return nil }
        return unifiedServers.first { $0.name == name }
    }

    func config(for tool: ToolKind) -> ToolConfig? {
        toolConfigs.first { $0.tool == tool }
    }

    func serverCount(for tool: ToolKind) -> Int {
        toolConfigs.first { $0.tool == tool }?.serverCount ?? 0
    }

    // MARK: - Actions

    func loadAll() {
        isLoading = true
        errorMessage = nil

        toolConfigs = discoveryService.discoverAllConfigs()
        syncProfiles = (try? syncService.loadProfiles()) ?? []

        setupFileWatchers()
        isLoading = false
    }

    /// Call once at app startup. Migrates any vals.zsh entries into the
    /// Keychain, loads the entries into state, and injects them all into the
    /// launchd env so GUI-launched MCP servers can read them immediately.
    /// Kept separate from loadAll() so Keychain I/O never blocks config reloads.
    func loadKeychain() {
        keychainService.migrateFromValsFileIfNeeded(valsService)
        valsEntries = keychainService.loadEntries()
        keychainService.injectAllIntoEnvironment()
    }

    func addServer(_ server: MCPServer, to tools: [ToolKind]) {
        do {
            for tool in tools {
                try configService.addServer(server, to: tool)
            }
            loadAll()
        } catch {
            errorMessage = "Failed to add server: \(error.localizedDescription)"
        }
    }

    func updateServer(_ server: MCPServer, replacing oldName: String? = nil, in tools: [ToolKind]) {
        do {
            for tool in tools {
                try configService.updateServer(server, in: tool, replacingKey: oldName)
            }
            loadAll()
        } catch {
            errorMessage = "Failed to update server: \(error.localizedDescription)"
        }
    }

    func deleteServer(named name: String, from tools: [ToolKind]) {
        do {
            for tool in tools {
                try configService.deleteServer(named: name, from: tool)
            }
            // Remove sync profile if exists
            syncProfiles.removeAll { $0.serverName == name }
            try? syncService.saveProfiles(syncProfiles)
            if selectedServerName == name {
                selectedServerName = nil
                showInspector = false
            }
            loadAll()
        } catch {
            errorMessage = "Failed to delete server: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync

    func updateSyncProfile(for serverName: String, master: ToolKind, replicas: [ToolKind]) {
        // Pause file watchers so our own config writes don't trigger
        // redundant loadAll() calls while we're still mid-update.
        fileWatcher.stopAll()

        // Remove existing profile for this server
        syncProfiles.removeAll { $0.serverName == serverName }

        if !replicas.isEmpty {
            let profile = SyncProfile(
                serverName: serverName,
                masterTool: master,
                replicaTools: replicas
            )
            syncProfiles.append(profile)

            // Immediately sync
            do {
                try syncService.syncServer(named: serverName, profile: profile)
            } catch {
                errorMessage = "Failed to sync: \(error.localizedDescription)"
            }
        }

        do {
            try syncService.saveProfiles(syncProfiles)
        } catch {
            errorMessage = "Failed to save sync profiles: \(error.localizedDescription)"
        }

        // Reload everything (also re-establishes file watchers).
        loadAll()
    }

    func syncProfile(for serverName: String) -> SyncProfile? {
        syncService.profile(for: serverName, in: syncProfiles)
    }

    func isReplica(tool: ToolKind, serverName: String) -> Bool {
        syncService.isReplica(tool: tool, serverName: serverName, profiles: syncProfiles)
    }

    // MARK: - File Watching

    private func setupFileWatchers() {
        fileWatcher.stopAll()
        for config in toolConfigs {
            let url = config.filePath
            fileWatcher.watch(url: url) { [weak self] in
                Task { @MainActor in
                    self?.loadAll()
                }
            }
        }
    }

    // MARK: - Keychain (vals.zsh)

    func addValsEntry(_ entry: ValsEntry) {
        do {
            try keychainService.addEntry(entry)
            valsEntries = keychainService.loadEntries()
        } catch {
            errorMessage = "Failed to add key: \(error.localizedDescription)"
        }
    }

    func updateValsEntry(_ entry: ValsEntry) {
        do {
            try keychainService.updateEntry(entry)
            valsEntries = keychainService.loadEntries()
        } catch {
            errorMessage = "Failed to update key: \(error.localizedDescription)"
        }
    }

    func deleteValsEntry(key: String) {
        do {
            try keychainService.deleteEntry(key: key)
            valsEntries = keychainService.loadEntries()
        } catch {
            errorMessage = "Failed to delete key: \(error.localizedDescription)"
        }
    }

    // MARK: - Import / Export

    func exportServers(_ servers: [MCPServer]) -> Data? {
        var dict: [String: Any] = [:]
        for server in servers {
            let entry = ServerEntry.from(server)
            guard let data = try? JSONEncoder().encode(entry),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            dict[server.name] = obj.filter { _, v in !(v is NSNull) }
        }
        let wrapper: [String: Any] = ["mcpServers": dict]
        return try? JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
    }

    func importServers(from data: Data) -> [MCPServer]? {
        let parser = ConfigParser()
        // Try mcpServers key first, then servers
        if let servers = try? parser.parseServers(from: data, tool: .claudeDesktop), !servers.isEmpty {
            return Array(servers.values)
        }
        if let servers = try? parser.parseServers(from: data, tool: .vscodeCopilot), !servers.isEmpty {
            return Array(servers.values)
        }
        return nil
    }
}
