import SwiftUI

struct KeychainView: View {

    @Environment(AppViewModel.self) private var viewModel

    @State private var editingEntry: ValsEntry?
    @State private var showAddSheet = false
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: ValsEntry?

    var body: some View {
        VStack(spacing: 0) {
            // Zshrc status banner
            if !viewModel.isValsSourcedInZshrc {
                zshrcBanner
            }

            if viewModel.valsEntries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Key", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            KeyEntryEditor(mode: .add) { entry in
                viewModel.addValsEntry(entry)
            }
        }
        .sheet(item: $editingEntry) { entry in
            KeyEntryEditor(mode: .edit(entry)) { updated in
                viewModel.updateValsEntry(updated)
            }
        }
        .alert("Delete Key?", isPresented: $showDeleteConfirmation, presenting: entryToDelete) { entry in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteValsEntry(key: entry.key)
            }
        } message: { entry in
            Text("This will remove \"\(entry.key)\" from vals.zsh. MCP servers referencing this variable will lose access to it.")
        }
    }

    // MARK: - Subviews

    private var zshrcBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("vals.zsh is not sourced in your .zshrc")
                    .font(.headline)
                Text("Your MCP servers won't see these environment variables until .zshrc sources the file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Fix Now") {
                viewModel.addValsSourceToZshrc()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No Environment Keys")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Add API tokens and secrets here. MCP servers can reference\nthem as environment variables.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("Add Your First Key", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.valsEntries) { entry in
                    KeyRow(
                        entry: entry,
                        onEdit: { editingEntry = entry },
                        onDelete: {
                            entryToDelete = entry
                            showDeleteConfirmation = true
                        },
                        onCopy: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.value, forType: .string)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Key Row

private struct KeyRow: View {
    let entry: ValsEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void

    @State private var isHovering = false
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.key)
                    .font(.body.weight(.medium).monospaced())
                Text(isRevealed ? entry.value : maskedValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 4) {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(isRevealed ? "Hide value" : "Reveal value")

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy value")

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Edit")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.accentColor.opacity(0.05) : .clear)
        }
        .onHover { isHovering = $0 }
    }

    private var maskedValue: String {
        let v = entry.value
        if v.count <= 8 { return String(repeating: "\u{2022}", count: v.count) }
        let prefix = String(v.prefix(4))
        let suffix = String(v.suffix(4))
        return prefix + String(repeating: "\u{2022}", count: min(v.count - 8, 20)) + suffix
    }
}

// MARK: - Key Entry Editor

private enum EditorMode: Identifiable {
    case add
    case edit(ValsEntry)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let e): "edit-\(e.key)"
        }
    }
}

private struct KeyEntryEditor: View {
    let mode: EditorMode
    let onSave: (ValsEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var key: String = ""
    @State private var value: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Key" : "Add Key")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Variable Name").font(.headline)
                    TextField("e.g. OPENAI_API_KEY", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                        .disabled(isEditing)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Value").font(.headline)
                    TextField("Paste your token or secret", text: $value)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                Text("This will be stored in ~/.config/vals.zsh as an export.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            HStack {
                Spacer()
                Button(isEditing ? "Update" : "Add") {
                    let sanitizedKey = key.trimmingCharacters(in: .whitespaces)
                        .uppercased()
                        .replacingOccurrences(of: " ", with: "_")
                    onSave(ValsEntry(key: sanitizedKey, value: value.trimmingCharacters(in: .whitespaces)))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || value.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 450)
        .onAppear {
            if case .edit(let entry) = mode {
                key = entry.key
                value = entry.value
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
}
