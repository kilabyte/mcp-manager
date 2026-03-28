import Foundation

/// A single environment variable entry from vals.zsh.
struct ValsEntry: Identifiable, Equatable, Sendable {
    var id: String { key }
    var key: String
    var value: String
}

/// Reads, writes, and manages environment variable tokens in ~/.config/vals.zsh.
final class ValsFileService: Sendable {

    private nonisolated(unsafe) let fm = FileManager.default

    var filePath: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/vals.zsh")
    }

    var fileExists: Bool {
        fm.fileExists(atPath: filePath.path)
    }

    // MARK: - Read

    func loadEntries() throws -> [ValsEntry] {
        guard fm.fileExists(atPath: filePath.path) else { return [] }
        let contents = try String(contentsOf: filePath, encoding: .utf8)
        return parseEntries(from: contents)
    }

    private func parseEntries(from text: String) -> [ValsEntry] {
        var entries: [ValsEntry] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("export ") else { continue }
            let afterExport = String(trimmed.dropFirst("export ".count))
            guard let eqIndex = afterExport.firstIndex(of: "=") else { continue }
            let key = String(afterExport[afterExport.startIndex..<eqIndex])
                .trimmingCharacters(in: .whitespaces)
            let value = String(afterExport[afterExport.index(after: eqIndex)...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !key.isEmpty else { continue }
            entries.append(ValsEntry(key: key, value: value))
        }
        return entries
    }

    // MARK: - Write

    func saveEntries(_ entries: [ValsEntry]) throws {
        // Ensure directory exists
        let dir = filePath.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Preserve comment header if it exists, otherwise add one
        var header = "# Local machine-specific values for shell sessions\n# Source from ~/.zshrc\n"
        if fm.fileExists(atPath: filePath.path) {
            let existing = try String(contentsOf: filePath, encoding: .utf8)
            let commentLines = existing.components(separatedBy: .newlines)
                .prefix(while: {
                    let t = $0.trimmingCharacters(in: .whitespaces)
                    return t.hasPrefix("#") || t.isEmpty
                })
            if !commentLines.isEmpty {
                header = commentLines.joined(separator: "\n") + "\n"
            }
        }

        var output = header
        if !header.hasSuffix("\n\n") && !header.hasSuffix("\n") {
            output += "\n"
        }
        for entry in entries.sorted(by: { $0.key < $1.key }) {
            output += "export \(entry.key)=\(entry.value)\n"
        }

        try output.write(to: filePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Zshrc source check

    /// Whether ~/.zshrc currently sources vals.zsh.
    var isSourcedInZshrc: Bool {
        let zshrc = fm.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
        guard let contents = try? String(contentsOf: zshrc, encoding: .utf8) else { return false }
        return contents.contains(".config/vals.zsh")
    }

    /// Add a source line to ~/.zshrc if not already present.
    func addSourceToZshrc() throws {
        let zshrc = fm.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
        var contents = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
        guard !contents.contains(".config/vals.zsh") else { return }
        let line = "\n# MCP Manager - environment tokens\n[ -f ~/.config/vals.zsh ] && source ~/.config/vals.zsh\n"
        contents.append(line)
        try contents.write(to: zshrc, atomically: true, encoding: .utf8)
    }

    // MARK: - Convenience mutations

    func addEntry(_ entry: ValsEntry) throws {
        var entries = try loadEntries()
        entries.removeAll { $0.key == entry.key }
        entries.append(entry)
        try saveEntries(entries)
    }

    func updateEntry(_ entry: ValsEntry) throws {
        var entries = try loadEntries()
        guard let idx = entries.firstIndex(where: { $0.key == entry.key }) else {
            entries.append(entry)
            try saveEntries(entries)
            return
        }
        entries[idx] = entry
        try saveEntries(entries)
    }

    func deleteEntry(key: String) throws {
        var entries = try loadEntries()
        entries.removeAll { $0.key == key }
        try saveEntries(entries)
    }
}
