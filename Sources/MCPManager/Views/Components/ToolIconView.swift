import SwiftUI

/// Displays the real app icon for a tool, falling back to an SF Symbol.
struct ToolIconView: View {
    let tool: ToolKind
    var size: CGFloat = 20

    var body: some View {
        if let icon = tool.appIcon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback for CLI tools (Claude Code) — use the Claude Desktop icon
            // with a terminal badge, or just an SF Symbol
            Image(systemName: tool.sfSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(tool.badgeColor)
        }
    }
}

/// A compact badge showing the tool's real icon with its short name.
struct ToolIconBadge: View {
    let tool: ToolKind

    var body: some View {
        HStack(spacing: 4) {
            ToolIconView(tool: tool, size: 14)
            Text(tool.shortName)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}
