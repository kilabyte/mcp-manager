import SwiftUI

struct SidebarView: View {

    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        List(selection: $vm.sidebarSelection) {
            // All Servers
            Label {
                HStack {
                    Text("All Servers")
                    Spacer()
                    Text("\(viewModel.unifiedServers.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            } icon: {
                Image(systemName: "server.rack")
            }
            .tag(SidebarSelection.allServers)

            // Tools
            Section("Tools") {
                ForEach(ToolKind.allCases) { tool in
                    ToolRow(tool: tool, serverCount: viewModel.serverCount(for: tool))
                        .tag(SidebarSelection.tool(tool))
                }
            }

            // Keychain
            Section("Keychain") {
                Label {
                    HStack {
                        Text("Environment Keys")
                        Spacer()
                        Text("\(viewModel.valsEntries.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                        if !viewModel.isValsSourcedInZshrc {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                    }
                } icon: {
                    Image(systemName: "key.fill")
                }
                .tag(SidebarSelection.keychain)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MCP Manager")
    }
}

// MARK: - Tool Row

private struct ToolRow: View {
    let tool: ToolKind
    let serverCount: Int

    var body: some View {
        Label {
            HStack {
                Text(tool.displayName)
                Spacer()
                if serverCount > 0 {
                    Text("\(serverCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Circle()
                    .fill(tool.isInstalled ? .green : .gray.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        } icon: {
            ToolIconView(tool: tool, size: 20)
        }
    }
}
