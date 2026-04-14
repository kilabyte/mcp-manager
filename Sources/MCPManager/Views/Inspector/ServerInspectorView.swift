import AppKit
import SwiftUI

struct ServerInspectorView: View {

    @Environment(AppViewModel.self) private var viewModel

    let server: UnifiedServer

    @State private var name: String = ""
    @State private var command: String = ""
    @State private var url: String = ""
    @State private var args: [String] = []
    @State private var envPairs: [EditableEnvPair] = []
    @State private var showDeleteConfirmation = false
    @State private var showOpenConfigPicker = false
    @State private var hasChanges = false

    // Sync state
    @State private var masterTool: ToolKind = .claudeDesktop
    @State private var replicaTools: Set<ToolKind> = []

    /// Installed tools, guaranteed non-empty for the Picker.
    private var installedTools: [ToolKind] {
        let tools = ToolKind.allCases.filter(\.isInstalled)
        return tools.isEmpty ? ToolKind.allCases : tools
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Server Details")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button {
                        viewModel.showInspector = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                // Server Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Name").font(.headline)
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { hasChanges = true }
                }

                // Command or URL
                if server.server.isURLBased {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL").font(.headline)
                        TextField("https://...", text: $url)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: url) { hasChanges = true }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command").font(.headline)
                        TextField("Command", text: $command)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: command) { hasChanges = true }
                    }

                    // Arguments
                    ArgsEditorView(args: $args)
                        .onChange(of: args) { hasChanges = true }
                }

                // Environment Variables
                EnvironmentEditorView(pairs: $envPairs)
                    .onChange(of: envPairs) { hasChanges = true }

                Divider()

                // Installed In — click any row to open that tool's config file
                VStack(alignment: .leading, spacing: 4) {
                    Text("Present In").font(.headline)
                    ForEach(Array(server.presentIn).sorted(by: { $0.rawValue < $1.rawValue })) { tool in
                        PresentInRow(tool: tool, isReplica: viewModel.isReplica(tool: tool, serverName: server.name)) {
                            NSWorkspace.shared.open(tool.configFilePath)
                        }
                    }
                }

                Divider()

                // Sync Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sync Settings").font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Master").font(.subheadline.weight(.medium))
                        Picker("Master", selection: $masterTool) {
                            ForEach(installedTools) { tool in
                                Label {
                                    Text(tool.displayName)
                                } icon: {
                                    ToolIconView(tool: tool, size: 16)
                                }
                                .tag(tool)
                            }
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keep in sync with").font(.subheadline.weight(.medium))
                        ForEach(ToolKind.allCases.filter { $0 != masterTool }) { tool in
                            Toggle(isOn: Binding(
                                get: { replicaTools.contains(tool) },
                                set: { isOn in
                                    if isOn { replicaTools.insert(tool) }
                                    else { replicaTools.remove(tool) }
                                }
                            )) {
                                HStack {
                                    ToolIconView(tool: tool, size: 18)
                                        .frame(width: 20)
                                    Text(tool.displayName)
                                    if !tool.isInstalled {
                                        Text("(not installed)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(!tool.isInstalled)
                        }
                    }

                    Button("Apply Sync") {
                        viewModel.updateSyncProfile(
                            for: server.name,
                            master: masterTool,
                            replicas: Array(replicaTools)
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if let profile = viewModel.syncProfile(for: server.name) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Syncing from \(profile.masterTool.displayName) to \(profile.replicaTools.count) tool(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Actions
                HStack {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges)
                    .keyboardShortcut("s")

                    Button {
                        openConfig()
                    } label: {
                        Label("Open Config", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Delete Server", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .onAppear { loadServerData() }
        .onChange(of: server.name) { loadServerData() }
        .alert("Delete Server?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteServer(
                    named: server.name,
                    from: Array(server.presentIn)
                )
            }
        } message: {
            Text("This will remove \"\(server.name)\" from all tools. This action cannot be undone.")
        }
        .confirmationDialog(
            "Open Config File",
            isPresented: $showOpenConfigPicker,
            titleVisibility: .visible
        ) {
            ForEach(Array(server.presentIn).sorted(by: { $0.rawValue < $1.rawValue })) { tool in
                Button(tool.displayName) {
                    NSWorkspace.shared.open(tool.configFilePath)
                }
            }
        } message: {
            Text("This server is present in \(server.presentIn.count) tools. Choose which config file to open.")
        }
    }

    private func openConfig() {
        let tools = Array(server.presentIn).sorted(by: { $0.rawValue < $1.rawValue })
        if tools.count == 1, let tool = tools.first {
            NSWorkspace.shared.open(tool.configFilePath)
        } else {
            showOpenConfigPicker = true
        }
    }

    private func loadServerData() {
        name = server.name
        command = server.server.command ?? ""
        url = server.server.url ?? ""
        args = server.server.args
        envPairs = server.server.env.map { EditableEnvPair(key: $0.key, value: $0.value) }
            .sorted(by: { $0.key < $1.key })

        // Load sync profile, clamping master to an installed tool so the Picker never crashes.
        let installed = installedTools
        if let profile = viewModel.syncProfile(for: server.name) {
            masterTool = installed.contains(profile.masterTool)
                ? profile.masterTool
                : installed.first ?? .claudeDesktop
            replicaTools = Set(profile.replicaTools)
        } else if let firstTool = server.presentIn.sorted(by: { $0.rawValue < $1.rawValue }).first,
                  installed.contains(firstTool) {
            masterTool = firstTool
            replicaTools = []
        } else {
            masterTool = installed.first ?? .claudeDesktop
            replicaTools = []
        }

        hasChanges = false
    }

    private func saveChanges() {
        var env: [String: String] = [:]
        for pair in envPairs where !pair.key.isEmpty {
            env[pair.key] = pair.value
        }

        let updatedServer: MCPServer
        if server.server.isURLBased {
            updatedServer = MCPServer(
                name: name,
                url: url,
                env: env,
                isEnabled: server.server.isEnabled
            )
        } else {
            updatedServer = MCPServer(
                name: name,
                command: command,
                args: args,
                env: env,
                isEnabled: server.server.isEnabled
            )
        }

        viewModel.updateServer(updatedServer, replacing: server.name, in: Array(server.presentIn))
        hasChanges = false
    }
}

// MARK: - Present In Row

private struct PresentInRow: View {
    let tool: ToolKind
    let isReplica: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                ToolIconView(tool: tool, size: 18)
                    .frame(width: 20)
                Text(tool.displayName)
                    .foregroundStyle(.primary)
                if isReplica {
                    Text("replica")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.accentColor.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Open \(tool.displayName) config file")
    }
}

// MARK: - Editable Env Pair

struct EditableEnvPair: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
}
