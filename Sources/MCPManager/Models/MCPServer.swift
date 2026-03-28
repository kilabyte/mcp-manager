import Foundation

struct MCPServer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var args: [String]
    var env: [String: String]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.isEnabled = isEnabled
    }
}

/// Raw entry as it appears in a tool's JSON config file.
/// Used for parsing/serializing — not for UI display.
struct ServerEntry: Codable {
    let command: String
    let args: [String]?
    let env: [String: String]?
    let type: String? // VS Code only: "stdio", "sse"
    let disabled: Bool?

    init(command: String, args: [String]? = nil, env: [String: String]? = nil, type: String? = nil, disabled: Bool? = nil) {
        self.command = command
        self.args = args
        self.env = env
        self.type = type
        self.disabled = disabled
    }

    func toMCPServer(name: String) -> MCPServer {
        MCPServer(
            name: name,
            command: command,
            args: args ?? [],
            env: env ?? [:],
            isEnabled: !(disabled ?? false)
        )
    }

    static func from(_ server: MCPServer, type: String? = nil) -> ServerEntry {
        ServerEntry(
            command: server.command,
            args: server.args.isEmpty ? nil : server.args,
            env: server.env.isEmpty ? nil : server.env,
            type: type,
            disabled: server.isEnabled ? nil : true
        )
    }
}
