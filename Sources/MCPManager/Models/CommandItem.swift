import Foundation

/// The type of command/configuration managed across platforms.
enum CommandKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case slashCommand   // Claude Code: ~/.claude/commands/*.md
    case rule           // Cursor: ~/.cursor/rules/*.mdc, Windsurf: ~/.codeium/windsurf/rules/*
    case hook           // Claude Code: settings.json hooks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .slashCommand: "Slash Commands"
        case .rule: "Rules"
        case .hook: "Hooks"
        }
    }

    var singularName: String {
        switch self {
        case .slashCommand: "Slash Command"
        case .rule: "Rule"
        case .hook: "Hook"
        }
    }

    var sfSymbol: String {
        switch self {
        case .slashCommand: "command"
        case .rule: "list.bullet.rectangle"
        case .hook: "arrow.triangle.branch"
        }
    }

    var supportedTools: [ToolKind] {
        switch self {
        case .slashCommand: [.claudeCode]
        case .rule: [.cursor, .windsurf, .vscodeCopilot, .claudeCode]
        case .hook: [.claudeCode]
        }
    }

    var itemDescription: String {
        switch self {
        case .slashCommand:
            "Custom slash commands extend your AI assistant with reusable prompts. Stored as markdown files."
        case .rule:
            "Rules provide persistent instructions and context to your AI assistant for every conversation."
        case .hook:
            "Hooks run shell commands automatically before or after specific events like tool calls."
        }
    }
}

/// A single command/rule/hook item managed by MCP Manager.
struct CommandItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var kind: CommandKind
    var content: String
    var tool: ToolKind
    var filePath: URL?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: CommandKind,
        content: String,
        tool: ToolKind,
        filePath: URL? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.content = content
        self.tool = tool
        self.filePath = filePath
        self.isEnabled = isEnabled
    }

    static func == (lhs: CommandItem, rhs: CommandItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
