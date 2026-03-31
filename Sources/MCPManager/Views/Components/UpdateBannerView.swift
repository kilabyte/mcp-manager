import SwiftUI

struct UpdateBannerView: View {

    let latestVersion: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.app.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Update Available — v\(latestVersion)")
                    .font(.headline)
                Text("A new version of MCP Manager is ready to download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("View Release") {
                NSWorkspace.shared.open(UpdateService.releasesURL)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding([.horizontal, .top])
    }
}
