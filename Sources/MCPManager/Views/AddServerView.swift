import SwiftUI

struct AddServerView: View {

    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var transportType = TransportType.stdio
    @State private var command = ""
    @State private var url = ""
    @State private var argsText = "" // newline-separated for simplicity
    @State private var envPairs: [EnvPair] = []
    @State private var selectedTools: Set<ToolKind> = []

    enum TransportType: String, CaseIterable {
        case stdio = "Command (stdio)"
        case url = "URL (SSE / HTTP)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add New Server")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name & Transport
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledField("Server Name") {
                            TextField("e.g. filesystem", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        Picker("Transport", selection: $transportType) {
                            ForEach(TransportType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Command + Args (stdio) or URL
                    if transportType == .stdio {
                        LabeledField("Command") {
                            TextField("e.g. npx, uvx, node", text: $command)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Arguments")
                                .font(.headline)
                            Text("One argument per line")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $argsText)
                                .font(.body.monospaced())
                                .frame(minHeight: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(.quaternary)
                                }
                        }
                    } else {
                        LabeledField("URL") {
                            TextField("https://...", text: $url)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Environment Variables
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Environment Variables")
                            .font(.headline)

                        ForEach($envPairs) { $pair in
                            HStack {
                                TextField("Key", text: $pair.key)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 150)
                                TextField("Value", text: $pair.value)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    envPairs.removeAll { $0.id == pair.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            envPairs.append(EnvPair())
                        } label: {
                            Label("Add Variable", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    // Tool selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add to")
                            .font(.headline)

                        ForEach(ToolKind.allCases) { tool in
                            Toggle(isOn: Binding(
                                get: { selectedTools.contains(tool) },
                                set: { isOn in
                                    if isOn { selectedTools.insert(tool) }
                                    else { selectedTools.remove(tool) }
                                }
                            )) {
                                HStack(spacing: 6) {
                                    ToolIconView(tool: tool, size: 18)
                                    Text(tool.displayName)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(!tool.isInstalled)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Add Server") {
                    addServer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 550)
        .onAppear {
            // Pre-select installed tools
            selectedTools = Set(ToolKind.allCases.filter(\.isInstalled))
        }
    }

    private var isValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let hasConnection = transportType == .stdio
            ? !command.trimmingCharacters(in: .whitespaces).isEmpty
            : !url.trimmingCharacters(in: .whitespaces).isEmpty
        return hasName && hasConnection && !selectedTools.isEmpty
    }

    private func addServer() {
        var env: [String: String] = [:]
        for pair in envPairs where !pair.key.isEmpty {
            env[pair.key] = pair.value
        }

        let server: MCPServer
        if transportType == .url {
            server = MCPServer(
                name: name.trimmingCharacters(in: .whitespaces),
                url: url.trimmingCharacters(in: .whitespaces),
                env: env
            )
        } else {
            let args = argsText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            server = MCPServer(
                name: name.trimmingCharacters(in: .whitespaces),
                command: command.trimmingCharacters(in: .whitespaces),
                args: args,
                env: env
            )
        }

        viewModel.addServer(server, to: Array(selectedTools))
        dismiss()
    }
}

// MARK: - Helpers

struct EnvPair: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.headline)
            content
        }
    }
}
