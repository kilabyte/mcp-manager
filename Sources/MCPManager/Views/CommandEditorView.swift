import SwiftUI

/// Modal editor for creating or editing a command item (slash command, rule, or hook).
struct CommandEditorView: View {
    let mode: CommandEditorMode
    let onSave: (CommandItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var content: String = ""
    @State private var selectedTool: ToolKind = .claudeCode

    private var kind: CommandKind {
        switch mode {
        case .add(let kind): kind
        case .edit(let item): item.kind
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var availableTools: [ToolKind] {
        kind.supportedTools.filter { $0.isInstalled }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 560, height: 520)
        .onAppear {
            if case .edit(let item) = mode {
                name = item.name
                content = item.content
                selectedTool = item.tool
            } else if let first = availableTools.first {
                selectedTool = first
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit \(kind.singularName)" : "Add \(kind.singularName)")
                .font(.title2.weight(.semibold))
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.headline)
                    TextField(namePlaceholder, text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                // Tool selection
                if availableTools.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Platform").font(.headline)
                        Picker("Platform", selection: $selectedTool) {
                            ForEach(availableTools) { tool in
                                Label(tool.displayName, systemImage: tool.sfSymbol)
                                    .tag(tool)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } else if let tool = availableTools.first {
                    HStack(spacing: 6) {
                        Text("Platform:").font(.headline)
                        Label(tool.displayName, systemImage: tool.sfSymbol)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content").font(.headline)
                    TextEditor(text: $content)
                        .font(.body.monospaced())
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary)
                        )
                }

                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(isEditing ? "Update" : "Add") {
                let sanitizedName = name
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "/", with: "-")

                let item = CommandItem(
                    id: existingID ?? UUID(),
                    name: sanitizedName,
                    kind: kind,
                    content: content,
                    tool: selectedTool,
                    filePath: existingFilePath,
                    isEnabled: true
                )
                onSave(item)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    // MARK: - Helpers

    private var existingID: UUID? {
        if case .edit(let item) = mode { return item.id }
        return nil
    }

    private var existingFilePath: URL? {
        if case .edit(let item) = mode { return item.filePath }
        return nil
    }

    private var namePlaceholder: String {
        switch kind {
        case .slashCommand: "e.g. review-code"
        case .rule: "e.g. coding-standards"
        case .hook: "e.g. PreToolUse"
        }
    }

    private var helpText: String {
        switch kind {
        case .slashCommand:
            "Slash commands are stored as markdown files. Use $ARGUMENTS for user input. Available as /\(name.isEmpty ? "command-name" : name) in Claude Code."
        case .rule:
            "Rules are loaded automatically by the AI assistant. Write instructions, coding standards, or context in markdown format."
        case .hook:
            "Hooks are JSON objects with a \"command\" field. They run automatically on events like PreToolUse, PostToolUse, etc."
        }
    }
}

// MARK: - Editor Mode

enum CommandEditorMode: Identifiable {
    case add(CommandKind)
    case edit(CommandItem)

    var id: String {
        switch self {
        case .add(let kind): "add-\(kind.rawValue)"
        case .edit(let item): "edit-\(item.id.uuidString)"
        }
    }
}
