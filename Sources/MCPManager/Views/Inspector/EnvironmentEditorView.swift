import SwiftUI

struct EnvironmentEditorView: View {

    @Binding var pairs: [EditableEnvPair]
    @State private var revealedKeys: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Environment Variables")
                .font(.headline)

            if pairs.isEmpty {
                Text("No environment variables")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach($pairs) { $pair in
                HStack(spacing: 8) {
                    TextField("Key", text: $pair.key)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                        .font(.body.monospaced())

                    if revealedKeys.contains(pair.id) {
                        TextField("Value", text: $pair.value)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                    } else {
                        SecureField("Value", text: $pair.value)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        if revealedKeys.contains(pair.id) {
                            revealedKeys.remove(pair.id)
                        } else {
                            revealedKeys.insert(pair.id)
                        }
                    } label: {
                        Image(systemName: revealedKeys.contains(pair.id) ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(revealedKeys.contains(pair.id) ? "Hide value" : "Show value")

                    Button {
                        pairs.removeAll { $0.id == pair.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                pairs.append(EditableEnvPair(key: "", value: ""))
            } label: {
                Label("Add Variable", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
