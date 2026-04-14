import Foundation

/// Discovers and manages slash commands, rules, and hooks across supported platforms.
final class CommandService: Sendable {

    private nonisolated(unsafe) let fm = FileManager.default

    // MARK: - Discovery

    /// Discover all command items of a given kind across all installed tools.
    func discoverCommands(kind: CommandKind) -> [CommandItem] {
        var items: [CommandItem] = []
        for tool in kind.supportedTools where tool.isInstalled {
            items.append(contentsOf: discoverCommands(kind: kind, for: tool))
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Discover commands of a given kind for a specific tool.
    func discoverCommands(kind: CommandKind, for tool: ToolKind) -> [CommandItem] {
        switch kind {
        case .slashCommand:
            return discoverSlashCommands(for: tool)
        case .rule:
            return discoverRules(for: tool)
        case .hook:
            return discoverHooks(for: tool)
        }
    }

    // MARK: - CRUD

    func addCommand(_ item: CommandItem) throws {
        switch item.kind {
        case .slashCommand:
            try writeFileCommand(item, directory: slashCommandDirectory(for: item.tool), ext: "md")
        case .rule:
            try writeFileCommand(item, directory: ruleDirectory(for: item.tool), ext: ruleExtension(for: item.tool))
        case .hook:
            try writeHook(item)
        }
    }

    func updateCommand(_ item: CommandItem, oldName: String? = nil) throws {
        // If renamed, delete the old file first
        if let oldName, oldName != item.name, item.kind != .hook {
            let dir: URL?
            let ext: String
            switch item.kind {
            case .slashCommand:
                dir = slashCommandDirectory(for: item.tool)
                ext = "md"
            case .rule:
                dir = ruleDirectory(for: item.tool)
                ext = ruleExtension(for: item.tool)
            case .hook:
                dir = nil
                ext = ""
            }
            if let dir {
                let oldFile = dir.appendingPathComponent("\(oldName).\(ext)")
                try? fm.removeItem(at: oldFile)
            }
        }

        switch item.kind {
        case .slashCommand:
            try writeFileCommand(item, directory: slashCommandDirectory(for: item.tool), ext: "md")
        case .rule:
            try writeFileCommand(item, directory: ruleDirectory(for: item.tool), ext: ruleExtension(for: item.tool))
        case .hook:
            try writeHook(item)
        }
    }

    func deleteCommand(_ item: CommandItem) throws {
        switch item.kind {
        case .slashCommand, .rule:
            if let filePath = item.filePath {
                try fm.removeItem(at: filePath)
            }
        case .hook:
            try deleteHook(item)
        }
    }

    // MARK: - Slash Commands (File-based)

    private func slashCommandDirectory(for tool: ToolKind) -> URL? {
        let home = fm.homeDirectoryForCurrentUser
        switch tool {
        case .claudeCode:
            return home.appendingPathComponent(".claude/commands")
        default:
            return nil
        }
    }

    private func discoverSlashCommands(for tool: ToolKind) -> [CommandItem] {
        guard let dir = slashCommandDirectory(for: tool) else { return [] }
        return readMarkdownFiles(in: dir, kind: .slashCommand, tool: tool, ext: "md")
    }

    // MARK: - Rules (File-based)

    private func ruleDirectory(for tool: ToolKind) -> URL? {
        let home = fm.homeDirectoryForCurrentUser
        switch tool {
        case .claudeCode:
            return home.appendingPathComponent(".claude/settings")
        case .cursor:
            return home.appendingPathComponent(".cursor/rules")
        case .windsurf:
            return home.appendingPathComponent(".codeium/windsurf/rules")
        case .vscodeCopilot:
            return home.appendingPathComponent(".vscode/rules")
        default:
            return nil
        }
    }

    private func ruleExtension(for tool: ToolKind) -> String {
        switch tool {
        case .cursor: "mdc"
        default: "md"
        }
    }

    private func discoverRules(for tool: ToolKind) -> [CommandItem] {
        guard let dir = ruleDirectory(for: tool) else { return [] }
        let ext = ruleExtension(for: tool)
        return readMarkdownFiles(in: dir, kind: .rule, tool: tool, ext: ext)
    }

    // MARK: - Hooks (JSON-based in settings)

    private func settingsFilePath(for tool: ToolKind) -> URL? {
        let home = fm.homeDirectoryForCurrentUser
        switch tool {
        case .claudeCode:
            return home.appendingPathComponent(".claude/settings.json")
        default:
            return nil
        }
    }

    private func discoverHooks(for tool: ToolKind) -> [CommandItem] {
        guard let settingsPath = settingsFilePath(for: tool),
              let data = try? Data(contentsOf: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return []
        }

        var items: [CommandItem] = []
        for (eventName, value) in hooks {
            if let hookArray = value as? [[String: Any]] {
                for (index, hookDef) in hookArray.enumerated() {
                    let command = hookDef["command"] as? String ?? ""
                    let hookName = hookArray.count > 1 ? "\(eventName) (\(index + 1))" : eventName
                    let enabled = !(hookDef["disabled"] as? Bool ?? false)

                    // Serialize the hook definition back to readable JSON
                    let content: String
                    if let jsonData = try? JSONSerialization.data(withJSONObject: hookDef, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
                       let jsonStr = String(data: jsonData, encoding: .utf8) {
                        content = jsonStr
                    } else {
                        content = command
                    }

                    items.append(CommandItem(
                        name: hookName,
                        kind: .hook,
                        content: content,
                        tool: tool,
                        filePath: settingsPath,
                        isEnabled: enabled
                    ))
                }
            }
        }
        return items
    }

    private func writeHook(_ item: CommandItem) throws {
        guard let settingsPath = settingsFilePath(for: item.tool) else { return }

        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        var hooks = json["hooks"] as? [String: Any] ?? [:]

        // Parse the content as JSON hook definition
        let hookDef: [String: Any]
        if let contentData = item.content.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            hookDef = parsed
        } else {
            hookDef = ["command": item.content]
        }

        // Extract event name (strip index suffix like " (1)")
        let eventName = item.name.replacingOccurrences(
            of: #" \(\d+\)$"#, with: "", options: .regularExpression
        )

        var eventHooks = hooks[eventName] as? [[String: Any]] ?? []
        // If updating existing, try to match; otherwise append
        if eventHooks.isEmpty {
            eventHooks = [hookDef]
        } else {
            eventHooks = [hookDef]
        }

        hooks[eventName] = eventHooks
        json["hooks"] = hooks

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: settingsPath, options: .atomic)
    }

    private func deleteHook(_ item: CommandItem) throws {
        guard let settingsPath = settingsFilePath(for: item.tool) else { return }

        guard let data = try? Data(contentsOf: settingsPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return
        }

        let eventName = item.name.replacingOccurrences(
            of: #" \(\d+\)$"#, with: "", options: .regularExpression
        )
        hooks.removeValue(forKey: eventName)
        json["hooks"] = hooks.isEmpty ? nil : hooks

        let updated = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try updated.write(to: settingsPath, options: .atomic)
    }

    // MARK: - File Helpers

    private func readMarkdownFiles(in directory: URL, kind: CommandKind, tool: ToolKind, ext: String) -> [CommandItem] {
        guard fm.fileExists(atPath: directory.path) else { return [] }

        var items: [CommandItem] = []
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == ext.lowercased() else { continue }
            let name = fileURL.deletingPathExtension().lastPathComponent
            let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""

            items.append(CommandItem(
                name: name,
                kind: kind,
                content: content,
                tool: tool,
                filePath: fileURL,
                isEnabled: true
            ))
        }
        return items
    }

    private func writeFileCommand(_ item: CommandItem, directory: URL?, ext: String) throws {
        guard let directory else { return }

        // Create directory if needed
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let filePath = directory.appendingPathComponent("\(item.name).\(ext)")
        try item.content.write(to: filePath, atomically: true, encoding: .utf8)
    }
}
