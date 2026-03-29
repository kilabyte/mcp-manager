# MCP Manager

[![Build macOS App](https://github.com/kilabyte/mcp-manager/actions/workflows/build.yml/badge.svg)](https://github.com/kilabyte/mcp-manager/actions/workflows/build.yml)

A native macOS app for managing MCP (Model Context Protocol) servers across all your AI coding tools from a single interface.

## Install

Download the latest `MCP-Manager.zip` from [Releases](https://github.com/kilabyte/mcp-manager/releases), unzip, and drag **MCP Manager.app** to your Applications folder.

## Features

### Unified Server Management
- View and manage all MCP servers across Claude Desktop, Claude Code, Cursor, Windsurf, and VS Code from one place
- Add, edit, duplicate, and delete servers with changes written directly to each tool's config file
- Real-time file watching — external config changes are picked up automatically

### Multi-Tool Sync
- Designate a master tool for each server and sync its configuration to other tools
- Keep server configs consistent across your entire workflow without manual copy-paste

### Environment Key Manager
- Store API tokens and secrets securely in the **macOS Keychain** (not a plaintext file)
- Add, edit, delete, copy, and reveal/hide values
- Keys are injected into your environment via `launchctl setenv` every time MCP Manager launches, so Claude Desktop, Cursor, and other GUI-launched tools automatically inherit them — no shell sourcing required

### Import / Export
- Import MCP server configurations from JSON files
- Export all servers to a shareable JSON format

---

## Using Environment Keys in MCP Servers

Keys stored in the **Keychain** section can be referenced directly by name in any MCP server's environment variables. MCP Manager injects them into the macOS launch environment each time it starts, so the values are available to all tools without ever being written to a config file.

### 1. Add a key in the Keychain section

Open MCP Manager → click **Keychain** in the sidebar → click **+** to add a key.

For example, add:

| Key | Value |
|-----|-------|
| `OPENAI_API_KEY` | `sk-...` |
| `GITHUB_TOKEN` | `ghp_...` |

### 2. Reference the key in an MCP server's environment

Open the server in the inspector → go to the **Environment** tab → add a variable using the same key name and `$KEY_NAME` as the value:

| Variable | Value |
|----------|-------|
| `OPENAI_API_KEY` | `$OPENAI_API_KEY` |

> **How it works:** MCP Manager calls `launchctl setenv OPENAI_API_KEY <actual value>` at startup. This sets the variable in the macOS launch environment. When Claude Desktop, Cursor, or any other GUI-launched tool starts an MCP server subprocess, it inherits that environment — so `$OPENAI_API_KEY` resolves to the real value automatically.

### 3. Keep MCP Manager running at login

For the injection to be in place before you open Claude Desktop or Cursor, add MCP Manager to **System Settings → General → Login Items**. That way the keys are always available from the moment you log in.

> **Note:** The actual secret values are never written to your MCP config files — only the variable name reference (e.g., `$OPENAI_API_KEY`) appears in JSON. The secrets live exclusively in the macOS Keychain.

---

## Supported Tools

| Tool | Config Path |
|------|------------|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Claude Code | `~/.claude.json` |
| Cursor | `~/.cursor/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |
| VS Code | `~/.vscode/mcp.json` |

## Requirements

- macOS 15.0+
- Swift 6.1+

## Build from Source

```bash
# Build and create .app bundle
./Scripts/bundle.sh

# Launch
open ".build/debug/MCP Manager.app"
```

For quick development iteration:

```bash
swift build && .build/debug/MCPManager
```

## Project Structure

```
Sources/MCPManager/
├── App/                    # App entry point
├── Models/                 # Data models (MCPServer, ToolKind, SyncProfile, ToolConfig)
├── Services/               # Business logic
│   ├── ConfigFileService   # Reads/writes tool config files with backup support
│   ├── ConfigParser        # Parses JSON config formats
│   ├── DiscoveryService    # Discovers installed tools and their configs
│   ├── FileWatcherService  # Watches config files for external changes
│   ├── KeychainService     # Stores env keys in macOS Keychain + launchctl injection
│   ├── SyncService         # Handles master/replica sync between tools
│   └── ValsFileService     # Legacy vals.zsh reader (migration use only)
├── ViewModels/             # AppViewModel (central state)
└── Views/                  # SwiftUI views
    ├── Cards/              # Server grid cards
    ├── Components/         # Reusable views (ToolIconView)
    ├── Inspector/          # Server detail editor
    └── Sidebar/            # Navigation sidebar
```

## License

Free to use, modify, and distribute for any purpose — including commercially as a tool. You may not sell this software or charge for it directly. See [LICENSE](LICENSE) for full terms.
