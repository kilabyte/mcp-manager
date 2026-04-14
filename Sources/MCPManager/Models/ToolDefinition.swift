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

    /// The JSON root key that holds MCP server definitions.
    var rootKey: String {
        switch self {
        case .vscodeCopilot: "servers"
        default: "mcpServers"
        }
    }

    /// Whether VS Code requires the `type` field on each server entry.
    var requiresTypeField: Bool {
        self == .vscodeCopilot
    }

    /// True when the tool only supports stdio transport and URL-based servers
    /// must be wrapped with mcp-remote as a bridge.
    var stdioOnly: Bool {
        self == .claudeDesktop
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
