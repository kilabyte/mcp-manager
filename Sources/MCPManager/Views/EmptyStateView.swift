import SwiftUI

struct EmptyStateView: View {

    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)

            if viewModel.installedTools.isEmpty {
                Text("No Supported Tools Detected")
                    .font(.title2.weight(.semibold))

                Text("Install one of the supported AI tools to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ToolKind.allCases) { tool in
                        Label(tool.displayName, systemImage: tool.sfSymbol)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            } else if !viewModel.searchText.isEmpty {
                Text("No Results")
                    .font(.title2.weight(.semibold))

                Text("No servers match \"\(viewModel.searchText)\"")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("No MCP Servers Found")
                    .font(.title2.weight(.semibold))

                Text("Add your first server or scan for existing configurations.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        viewModel.showAddServerSheet = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.loadAll()
                    } label: {
                        Label("Scan for Servers", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
