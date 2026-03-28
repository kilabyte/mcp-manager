import SwiftUI

struct ServerCardView: View {

    @Environment(AppViewModel.self) private var viewModel
    let server: UnifiedServer

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: name + menu
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                Text(server.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button("Edit") {
                        viewModel.selectedServerName = server.name
                        viewModel.showInspector = true
                    }
                    Button("Duplicate") {
                        duplicateServer()
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        viewModel.deleteServer(
                            named: server.name,
                            from: Array(server.presentIn)
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }

            // Command
            HStack(spacing: 4) {
                Text("$")
                    .foregroundStyle(.tertiary)
                Text(commandString)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            // Tool badges
            HStack(spacing: 4) {
                ForEach(Array(server.presentIn).sorted(by: { $0.rawValue < $1.rawValue })) { tool in
                    ToolBadge(tool: tool)
                }
                Spacer()
            }

            // Metadata + actions
            HStack {
                if !server.server.env.isEmpty {
                    Label("\(server.server.env.count) env", systemImage: "key")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !server.server.args.isEmpty {
                    Label("\(server.server.args.count) args", systemImage: "list.bullet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isHovering {
                    Button("Edit") {
                        viewModel.selectedServerName = server.name
                        viewModel.showInspector = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .frame(minHeight: 160)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected ? Color.accentColor : (isHovering ? Color.accentColor.opacity(0.3) : Color.clear),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .shadow(
                    color: .black.opacity(isHovering ? 0.15 : 0.05),
                    radius: isHovering ? 8 : 4,
                    y: isHovering ? 4 : 2
                )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            viewModel.selectedServerName = server.name
            viewModel.showInspector = true
        }
        .contextMenu {
            Button("Edit") {
                viewModel.selectedServerName = server.name
                viewModel.showInspector = true
            }
            Button("Duplicate") {
                duplicateServer()
            }
            Divider()
            Button("Delete", role: .destructive) {
                viewModel.deleteServer(
                    named: server.name,
                    from: Array(server.presentIn)
                )
            }
        }
    }

    private var commandString: String {
        ([server.server.command] + server.server.args).joined(separator: " ")
    }

    private var isSelected: Bool {
        viewModel.selectedServerName == server.name
    }

    private func duplicateServer() {
        var copy = server.server
        copy = MCPServer(
            name: "\(server.name)-copy",
            command: copy.command,
            args: copy.args,
            env: copy.env,
            isEnabled: copy.isEnabled
        )
        viewModel.addServer(copy, to: Array(server.presentIn))
    }
}

// MARK: - Tool Badge

struct ToolBadge: View {
    let tool: ToolKind

    var body: some View {
        Text(tool.shortName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tool.badgeColor, in: Capsule())
    }
}
