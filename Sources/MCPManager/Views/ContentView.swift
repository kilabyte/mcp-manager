import SwiftUI

struct ContentView: View {

    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView {
            SidebarView()
        } detail: {
            switch viewModel.sidebarSelection {
            case .keychain:
                KeychainView()
            case .commands(let kind):
                CommandListView(kind: kind)
            case .allServers, .tool:
                if viewModel.displayedServers.isEmpty {
                    EmptyStateView()
                } else {
                    ServerGridView()
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: searchPrompt)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.showAddServerSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .keyboardShortcut("n")

                Menu {
                    Button("Import Configuration...") {
                        importConfiguration()
                    }
                    Button("Export All Servers...") {
                        exportConfiguration()
                    }
                } label: {
                    Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
                }
            }
        }
        .sheet(isPresented: $vm.showAddServerSheet) {
            AddServerView()
        }
        .inspector(isPresented: $vm.showInspector) {
            if let server = viewModel.selectedServer {
                ServerInspectorView(server: server)
                    .inspectorColumnWidth(min: 320, ideal: 380, max: 450)
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var searchPrompt: String {
        switch viewModel.sidebarSelection {
        case .commands(let kind): "Search \(kind.displayName.lowercased())..."
        case .keychain: "Search keys..."
        default: "Search servers..."
        }
    }

    // MARK: - Import/Export

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Select an MCP server configuration file to import"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url),
              let servers = viewModel.importServers(from: data) else {
            viewModel.errorMessage = "Could not parse servers from the selected file."
            return
        }

        // Add imported servers to all installed tools
        let tools = viewModel.installedTools
        for server in servers {
            viewModel.addServer(server, to: tools)
        }
    }

    private func exportConfiguration() {
        let servers = viewModel.unifiedServers.map(\.server)
        guard let data = viewModel.exportServers(servers) else {
            viewModel.errorMessage = "Failed to export server configurations."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mcp-servers-export.json"
        panel.message = "Choose where to save the exported MCP server configurations"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            viewModel.errorMessage = "Failed to save export: \(error.localizedDescription)"
        }
    }
}
