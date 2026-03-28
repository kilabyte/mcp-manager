import SwiftUI

struct ArgsEditorView: View {

    @Binding var args: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arguments")
                .font(.headline)

            if args.isEmpty {
                Text("No arguments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(args.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, alignment: .trailing)

                    TextField("Argument", text: Binding(
                        get: { args[index] },
                        set: { args[index] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())

                    Button {
                        args.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                args.append("")
            } label: {
                Label("Add Argument", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
