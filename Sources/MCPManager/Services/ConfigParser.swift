import Foundation

/// Parses and serializes MCP server configurations from tool config files.
/// Uses JSONSerialization (not full-struct Codable) to preserve unknown keys on round-trip.
struct ConfigParser {

    enum ParseError: LocalizedError {
        case invalidJSON
        case rootKeyNotFound(String)
        case serializationFailed

        var errorDescription: String? {
            switch self {
            case .invalidJSON: "The config file contains invalid JSON."
            case .rootKeyNotFound(let key): "The config file does not contain a '\(key)' key."
            case .serializationFailed: "Failed to serialize the config data."
            }
        }
    }

    // MARK: - Parsing

    /// Parse servers from raw JSON data, given the tool's root key.
    func parseServers(from data: Data, tool: ToolKind) throws -> [String: MCPServer] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalidJSON
        }

        guard let serversDict = json[tool.rootKey] as? [String: Any] else {
            // Config file exists but has no servers key — that's ok, return empty
            return [:]
        }

        var result: [String: MCPServer] = [:]
        for (name, value) in serversDict {
            guard let serverDict = value as? [String: Any] else { continue }
            let entryData = try JSONSerialization.data(withJSONObject: serverDict)
            let entry = try JSONDecoder().decode(ServerEntry.self, from: entryData)
            result[name] = entry.toMCPServer(name: name)
        }
        return result
    }

    // MARK: - Serialization

    /// Serialize servers back into a full JSON document, preserving other keys from the existing data.
    func serializeServers(
        _ servers: [String: MCPServer],
        into existingData: Data?,
        tool: ToolKind
    ) throws -> Data {
        // Start from existing JSON or empty object
        var json: [String: Any]
        if let existingData,
           let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            json = existing
        } else {
            json = [:]
        }

        // Build the servers subtree
        var serversDict: [String: Any] = [:]
        for (name, server) in servers {
            let entry = ServerEntry.from(server, type: tool.requiresTypeField ? "stdio" : nil)
            let entryData = try JSONEncoder().encode(entry)
            guard var entryDict = try JSONSerialization.jsonObject(with: entryData) as? [String: Any] else {
                continue
            }
            // Remove null/nil values for clean JSON
            entryDict = entryDict.filter { _, v in !(v is NSNull) }
            serversDict[name] = entryDict
        }

        json[tool.rootKey] = serversDict

        guard JSONSerialization.isValidJSONObject(json) else {
            throw ParseError.serializationFailed
        }

        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        )
        return data
    }
}
