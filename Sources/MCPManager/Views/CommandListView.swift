import SwiftUI

struct CommandListView: View {

    let kind: CommandKind

    @Environment(AppViewModel.self) private var viewModel

    @State private var editingItem: CommandItem?
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: CommandItem?

    private var items: [CommandItem] {
        viewModel.displayedCommands(for: kind)
    }

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            if items.isEmpty && viewModel.searchText.isEmpty {
                emptyState
            } else if items.isEmpty {
                noResultsState
            } else {
                infoBanner
                itemList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddCommandSheet = true
                } label: {
                    Label("Add \(kind.singularName)", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $vm.showAddCommandSheet) {
            CommandEditorView(mode: .add(kind)) { item in
                viewModel.addCommand(item)
            }
        }
        .sheet(item: $editingItem) { item in
            CommandEditorView(mode: .edit(item)) { updated in
                viewModel.updateCommand(updated, oldName: item.name != updated.name ? item.name : nil)
            }
        }
        .alert("Delete \(kind.singularName)?", isPresented: $showDeleteConfirmation, presenting: itemToDelete) { item in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteCommand(item)
            }
        } message: { item in
            Text("This will permanently delete \"\(item.name)\" from \(item.tool.displayName). This cannot be undone.")
        }
    }

    // MARK: - Subviews

    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.sfSymbol)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(.headline)
                Text(kind.itemDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding([.horizontal, .top])
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: kind.sfSymbol)
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No \(kind.displayName)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(kind.itemDescription)
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if !kind.supportedTools.isEmpty {
                VStack(spacing: 4) {
                    Text("Supported by:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(kind.supportedTools) { tool in
                            Label(tool.displayName, systemImage: tool.sfSymbol)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }

            Button {
                viewModel.showAddCommandSheet = true
            } label: {
                Label("Add Your First \(kind.singularName)", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No Results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("No \(kind.displayName.lowercased()) match \"\(viewModel.searchText)\"")
                .font(.body)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items) { item in
                    CommandRow(
                        item: item,
                        onEdit: { editingItem = item },
                        onDelete: {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        },
                        onToggle: {
                            var updated = item
                            updated.isEnabled.toggle()
                            viewModel.updateCommand(updated)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let item: CommandItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    @State private var isHovering = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: item.kind.sfSymbol)
                    .foregroundStyle(item.isEnabled ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.body.weight(.medium).monospaced())
                            .strikethrough(!item.isEnabled, color: .secondary)
                        ToolIconBadge(tool: item.tool)
                    }
                    Text(contentPreview)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? 20 : 1)
                        .truncationMode(.tail)
                }

                Spacer()

                if isHovering {
                    HStack(spacing: 4) {
                        Button {
                            isExpanded.toggle()
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .help(isExpanded ? "Collapse" : "Expand")

                        if item.kind == .hook {
                            Button(action: onToggle) {
                                Image(systemName: item.isEnabled ? "pause.circle" : "play.circle")
                            }
                            .buttonStyle(.borderless)
                            .help(item.isEnabled ? "Disable" : "Enable")
                        }

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
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.accentColor.opacity(0.05) : .clear)
        }
        .onHover { isHovering = $0 }
    }

    private var contentPreview: String {
        let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "(empty)" }
        // Show first meaningful line
        let lines = trimmed.components(separatedBy: .newlines)
        return lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "(empty)"
    }
}
