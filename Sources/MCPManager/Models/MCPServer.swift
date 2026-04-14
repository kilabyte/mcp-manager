import Foundation

struct MCPServer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var command: String?
    var args: [String]
    var url: String?
    var env: [String: String]
    var isEnabled: Bool

    /// True when the server uses a remote URL (SSE / streamable HTTP) transport.
    var isURLBased: Bool { url != nil }

    /// Human-readable connection string shown in cards and search.
    var displayCommand: String {
        if let url { return url }
        return ([command].compactMap { $0 } + args).joined(separator: " ")
    }

    init(
        id: UUID = UUID(),
        name: String,
        command: String? = nil,
        args: [String] = [],
        url: String? = nil,
        env: [String: String] = [:],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.url = url
        self.env = env
        self.isEnabled = isEnabled
    }
}

/// Raw entry as it appears in a tool's JSON config file.
/// Used for parsing/serializing — not for UI display.
struct ServerEntry: Codable {
    let command: String?
    let args: [String]?
    let url: String?
    let env: [String: String]?
    let type: String? // VS Code: "stdio", "sse"; Cursor: "sse", "http"
    let disabled: Bool?

    init(command: String? = nil, args: [String]? = nil, url: String? = nil, env: [String: String]? = nil, type: String? = nil, disabled: Bool? = nil) {
        self.command = command
        self.args = args
        self.url = url
        self.env = env
        self.type = type
        self.disabled = disabled
    }

    func toMCPServer(name: String) -> MCPServer {
        MCPServer(
            name: name,
            command: command,
            args: args ?? [],
            url: url,
            env: env ?? [:],
            isEnabled: !(disabled ?? false)
        )
    }

    static func from(_ server: MCPServer, type: String? = nil) -> ServerEntry {
        let resolvedType: String?
        if let type {
            resolvedType = type
        } else if server.isURLBased {
            resolvedType = "sse"
        } else {
            resolvedType = nil
        }

        return ServerEntry(
            command: server.command,
            args: server.args.isEmpty ? nil : server.args,
            url: server.url,
            env: server.env.isEmpty ? nil : server.env,
            type: resolvedType,
            disabled: server.isEnabled ? nil : true
        )
    }
}
