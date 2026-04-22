import SwiftUI

// MARK: - "Coverage" tab — dot-matrix grid

struct CoverageView: View {
    @EnvironmentObject var store: ServerStore

    // Column config
    private let nameW: CGFloat  = 150
    private let cellW: CGFloat  = 28
    private let dotSize: CGFloat = 8

    var body: some View {
        let detected = store.detectedTools
        let servers  = store.allServerNames

        VStack(spacing: 0) {
            // ── Legend ────────────────────────────────────────────────
            legendSection(tools: detected)

            Divider()

            // ── Grid ──────────────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Column headers
                    headerRow(tools: detected)

                    Divider()

                    // Data rows
                    ForEach(Array(servers.enumerated()), id: \.element) { idx, name in
                        dataRow(name: name, tools: detected, idx: idx)
                    }
                }
            }
            .frame(maxHeight: 440)

            Divider()

            // ── Footer ────────────────────────────────────────────────
            HStack {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text("installed").font(.system(size: 10)).foregroundColor(.secondary)
                Circle().fill(Color.secondary.opacity(0.25)).frame(width: 7, height: 7)
                    .padding(.leading, 8)
                Text("not installed").font(.system(size: 10)).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Legend

    private func legendSection(tools: [ToolSummary]) -> some View {
        let chunks = stride(from: 0, to: tools.count, by: 5).map {
            Array(tools[$0..<min($0 + 5, tools.count)])
        }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                HStack(spacing: 10) {
                    ForEach(chunk) { tool in
                        HStack(spacing: 3) {
                            Text(tool.short)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.accentColor)
                            Text("=")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(tool.label)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Grid header row

    private func headerRow(tools: [ToolSummary]) -> some View {
        HStack(spacing: 0) {
            Text("server")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: nameW, alignment: .leading)

            ForEach(tools) { tool in
                Text(tool.short)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: cellW, alignment: .center)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Grid data row

    private func dataRow(name: String, tools: [ToolSummary], idx: Int) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: nameW, alignment: .leading)

            ForEach(tools) { tool in
                let has = tool.servers.contains { $0.name == name }
                Circle()
                    .fill(has ? Color.green : Color.secondary.opacity(0.2))
                    .frame(width: dotSize, height: dotSize)
                    .frame(width: cellW)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(idx % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
}
