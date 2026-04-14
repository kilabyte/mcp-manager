import AppKit
import Foundation
import SwiftUI

enum ToolKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case claudeDesktop
    case claudeCode
    case cursor
    case windsurf
    case vscodeCopilot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeDesktop: "Claude Desktop"
        case .claudeCode: "Claude Code"
        case .cursor: "Cursor"
        case .windsurf: "Windsurf"
        case .vscodeCopilot: "VS Code"
        }
    }

    var shortName: String {
        switch self {
        case .claudeDesktop: "CD"
        case .claudeCode: "CC"
        case .cursor: "CU"
        case .windsurf: "WS"
        case .vscodeCopilot: "VS"
        }
    }

    var sfSymbol: String {
        switch self {
        case .claudeDesktop: "desktopcomputer"
        case .claudeCode: "terminal"
        case .cursor: "cursorarrow.click"
        case .windsurf: "wind"
        case .vscodeCopilot: "chevron.left.forwardslash.chevron.right"
        }
    }

    var badgeColor: Color {
        switch self {
        case .claudeDesktop: .orange
        case .claudeCode: .orange
        case .cursor: .blue
        case .windsurf: .teal
        case .vscodeCopilot: .purple
        }
    }

    /// macOS bundle identifier used to load the real app icon.
    var bundleIdentifier: String? {
        switch self {
        case .claudeDesktop: "com.anthropic.claudefordesktop"
        case .claudeCode: nil // CLI tool, no bundle
        case .cursor: "com.todesktop.230313mzl4w4u92"
        case .windsurf: "com.exafunction.windsurf"
        case .vscodeCopilot: "com.microsoft.VSCode"
        }
    }

    /// Returns the NSImage for this tool's app icon, or nil if unavailable.
    @MainActor
    var appIcon: NSImage? {
        guard let bundleID = bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    // MARK: - Config Format

    /// Describes how a tool structures its MCP server config entries.
    struct ConfigFormat {
        /// JSON root key that holds the server definitions.
        let rootKey: String
        /// Whether the tool natively supports URL (SSE/HTTP) transport.
        /// When false, URL servers are bridged through mcp-remote.
        let supportsURL: Bool
        /// Whether each entry must include a `type` field ("stdio"/"sse").
        let includesType: Bool
    }

    /// Per-tool config format rules. This is the single source of truth for
    /// how each tool expects its MCP server entries to be structured.
    var configFormat: ConfigFormat {
        switch self {
        case .claudeDesktop: ConfigFormat(rootKey: "mcpServers", supportsURL: false, includesType: false)
        case .claudeCode:    ConfigFormat(rootKey: "mcpServers", supportsURL: true,  includesType: false)
        case .cursor:        ConfigFormat(rootKey: "mcpServers", supportsURL: true,  includesType: false)
        case .windsurf:      ConfigFormat(rootKey: "mcpServers", supportsURL: true,  includesType: false)
        case .vscodeCopilot: ConfigFormat(rootKey: "servers",    supportsURL: true,  includesType: true)
        }
    }

    /// Shorthand for the JSON root key.
    var rootKey: String { configFormat.rootKey }

    /// Produce the correct ServerEntry for this tool's config format.
    /// Handles transport bridging (mcp-remote) and type field injection.
    func serverEntry(for server: MCPServer) -> ServerEntry {
        let format = configFormat

        // Bridge URL servers through mcp-remote for stdio-only tools
        if server.isURLBased && !format.supportsURL, let url = server.url {
            return ServerEntry(
                command: "npx",
                args: ["-y", "mcp-remote", url],
                env: server.env.isEmpty ? nil : server.env,
                type: format.includesType ? "stdio" : nil,
                disabled: server.isEnabled ? nil : true
            )
        }

        return ServerEntry(
            command: server.command,
            args: server.args.isEmpty ? nil : server.args,
            url: server.url,
            env: server.env.isEmpty ? nil : server.env,
            type: format.includesType ? (server.isURLBased ? "sse" : "stdio") : nil,
            disabled: server.isEnabled ? nil : true
        )
    }

    /// Expanded config file path on macOS.
    var configFilePath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .claudeDesktop:
            return home
                .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        case .claudeCode:
            return home.appendingPathComponent(".claude.json")
        case .cursor:
            return home.appendingPathComponent(".cursor/mcp.json")
        case .windsurf:
            return home.appendingPathComponent(".codeium/windsurf/mcp_config.json")
        case .vscodeCopilot:
            return home.appendingPathComponent(".vscode/mcp.json")
        }
    }

    /// Check if the config file (or its parent directory) exists, suggesting the tool is installed.
    var isInstalled: Bool {
        let fm = FileManager.default
        let path = configFilePath.path
        if fm.fileExists(atPath: path) { return true }
        // Check parent directory exists (tool installed but no config yet)
        let parent = configFilePath.deletingLastPathComponent().path
        return fm.fileExists(atPath: parent)
    }
}
