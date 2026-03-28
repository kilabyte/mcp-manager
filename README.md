# MCP Manager

A native macOS app for managing MCP (Model Context Protocol) servers across all your AI coding tools from a single interface.

## Features

### Unified Server Management
- View and manage all MCP servers across Claude Desktop, Claude Code, Cursor, Windsurf, and VS Code from one place
- Add, edit, duplicate, and delete servers with changes written directly to each tool's config file
- Real-time file watching — external config changes are picked up automatically

### Multi-Tool Sync
- Designate a master tool for each server and sync its configuration to other tools
- Keep server configs consistent across your entire workflow without manual copy-paste

### Environment Key Manager
- Manage API tokens and secrets in `~/.config/vals.zsh`
- Add, edit, delete, copy, and reveal/hide values
- Detects whether `.zshrc` sources the file and offers a one-click fix

### Import / Export
- Import MCP server configurations from JSON files
- Export all servers to a shareable JSON format

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

## Build & Run

```bash
# Build and create .app bundle with dock icon
./Scripts/bundle.sh

# Launch
open ".build/debug/MCP Manager.app"
```

Or for quick development iteration:

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
│   ├── SyncService         # Handles master/replica sync between tools
│   └── ValsFileService     # Manages ~/.config/vals.zsh environment keys
├── ViewModels/             # AppViewModel (central state)
└── Views/                  # SwiftUI views
    ├── Cards/              # Server grid cards
    ├── Components/         # Reusable views (ToolIconView)
    ├── Inspector/          # Server detail editor
    └── Sidebar/            # Navigation sidebar
```

## License

MIT
