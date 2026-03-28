import SwiftUI

struct AddServerView: View {

    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var command = ""
    @State private var argsText = "" // newline-separated for simplicity
    @State private var envPairs: [EnvPair] = []
    @State private var selectedTools: Set<ToolKind> = []

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
                    // Name & Command
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledField("Server Name") {
                            TextField("e.g. filesystem", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField("Command") {
                            TextField("e.g. npx, uvx, node", text: $command)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Arguments
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
                                Label(tool.displayName, systemImage: tool.sfSymbol)
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !command.trimmingCharacters(in: .whitespaces).isEmpty
        && !selectedTools.isEmpty
    }

    private func addServer() {
        let args = argsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var env: [String: String] = [:]
        for pair in envPairs where !pair.key.isEmpty {
            env[pair.key] = pair.value
        }

        let server = MCPServer(
            name: name.trimmingCharacters(in: .whitespaces),
            command: command.trimmingCharacters(in: .whitespaces),
            args: args,
            env: env
        )

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
