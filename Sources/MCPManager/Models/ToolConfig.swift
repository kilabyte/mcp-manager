import Foundation

struct ToolConfig: Identifiable {
    let id: UUID
    let tool: ToolKind
    let filePath: URL
    var servers: [String: MCPServer]
    var lastModified: Date?

    init(
        id: UUID = UUID(),
        tool: ToolKind,
        filePath: URL,
        servers: [String: MCPServer] = [:],
        lastModified: Date? = nil
    ) {
        self.id = id
        self.tool = tool
        self.filePath = filePath
        self.servers = servers
        self.lastModified = lastModified
    }

    var serverCount: Int { servers.count }
    var sortedServerNames: [String] { servers.keys.sorted() }
}
