import SwiftUI

// MARK: - "By Tool" tab

struct ByToolView: View {
    @EnvironmentObject var store: ServerStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(Array(store.detectedTools.enumerated()), id: \.element.id) { idx, tool in
                    ToolSection(tool: tool)
                    if idx < store.detectedTools.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxHeight: 520)
    }
}

// MARK: - Per-tool collapsible section

struct ToolSection: View {
    let tool: ToolSummary
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }) {
                HStack {
                    Text(tool.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(tool.short)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.7))
                        .cornerRadius(4)

                    Spacer()

                    Text("\(tool.servers.count) server\(tool.servers.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            // Server list
            if expanded {
                if tool.servers.isEmpty {
                    Text("none")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                        .padding(.bottom, 8)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(tool.servers) { server in
                            ServerRow(server: server)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }
}

// MARK: - Individual server row

struct ServerRow: View {
    let server: ServerEntry

    private var tagColor: Color {
        server.transport == "stdio" ? .secondary : .cyan
    }

    private var detailText: String {
        // Clip long details to avoid wrapping
        let full = server.detail
        return full.count > 60 ? String(full.prefix(57)) + "…" : full
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(server.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Text(server.transport)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(tagColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(tagColor.opacity(0.12))
                .cornerRadius(3)

            Text(detailText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .padding(.vertical, 3)
    }
}
