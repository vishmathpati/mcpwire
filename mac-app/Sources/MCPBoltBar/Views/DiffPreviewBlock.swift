import SwiftUI

// MARK: - Diff preview shown in the Import flow.
// For each (server x tool) selection we compute a before/after from
// ConfigWriter.previewWrite and render added lines in green, removed lines in red.
// This is a simple line-level diff (longest-common-subsequence is overkill
// for the small JSON files MCP configs produce).

struct DiffPreviewBlock: View {
    let servers: [ParsedServer]
    let selectedTools: [String]
    let scope: ConfigScope
    let projectRoot: String?

    var body: some View {
        if selectedTools.isEmpty || servers.isEmpty {
            Text("Select at least one app to preview.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(selectedTools, id: \.self) { toolID in
                    previewForTool(toolID: toolID)
                }
            }
        }
    }

    @ViewBuilder
    private func previewForTool(toolID: String) -> some View {
        let effectiveScope: ConfigScope = (scope == .project
            && ToolSpecs.projectScopedTools.contains(toolID)) ? .project : .user
        let root = effectiveScope == .project ? projectRoot : nil

        if let spec = ToolSpecs.spec(for: toolID, scope: effectiveScope, projectRoot: root) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text(spec.path)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if effectiveScope == .project {
                        Text("(project)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
                .foregroundColor(.secondary)

                diffBody(toolID: toolID, scope: effectiveScope, projectRoot: root)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
                    )
            }
        } else {
            EmptyView()
        }
    }

    private func computeDiff(toolID: String, scope: ConfigScope, projectRoot: String?) -> [DiffLine]? {
        var currentBefore: String = ""
        var currentAfter:  String = ""
        var hadPreview = false
        for (idx, server) in servers.enumerated() {
            if let p = ConfigWriter.previewWrite(
                toolID: toolID,
                scope: scope,
                projectRoot: projectRoot,
                name: server.name,
                config: server.config
            ) {
                if idx == 0 { currentBefore = p.before }
                currentAfter = p.after
                hadPreview = true
            }
        }
        return hadPreview ? lineDiff(before: currentBefore, after: currentAfter) : nil
    }

    @ViewBuilder
    private func diffBody(toolID: String, scope: ConfigScope, projectRoot: String?) -> some View {
        if let lines = computeDiff(toolID: toolID, scope: scope, projectRoot: projectRoot) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 0) {
                        Text(line.symbol)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(line.color)
                            .frame(width: 14, alignment: .leading)
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(line.color)
                            .textSelection(.enabled)
                    }
                }
            }
        } else {
            Text("(format not previewable)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    struct DiffLine {
        enum Kind { case same, add, remove }
        let kind: Kind
        let text: String
        var symbol: String {
            switch kind {
            case .same:   return " "
            case .add:    return "+"
            case .remove: return "-"
            }
        }
        var color: Color {
            switch kind {
            case .same:   return .secondary
            case .add:    return .green
            case .remove: return .red
            }
        }
    }

    /// Very simple set-based diff: lines in after-but-not-in-before = add,
    /// lines in before-but-not-in-after = remove. Good enough for small
    /// JSON files and avoids pulling in a diff library.
    private func lineDiff(before: String, after: String) -> [DiffLine] {
        let beforeLines = before.components(separatedBy: "\n")
        let afterLines  = after.components(separatedBy: "\n")
        let beforeSet = Set(beforeLines)
        let afterSet  = Set(afterLines)

        var out: [DiffLine] = []
        // Walk "after" so the output is readable.
        for l in afterLines {
            if beforeSet.contains(l) {
                out.append(DiffLine(kind: .same, text: l))
            } else {
                out.append(DiffLine(kind: .add, text: l))
            }
        }
        // Append removed lines at the end.
        for l in beforeLines where !afterSet.contains(l) {
            out.append(DiffLine(kind: .remove, text: l))
        }
        // Cap length so the preview doesn't blow up.
        if out.count > 120 {
            return Array(out.prefix(120)) + [DiffLine(kind: .same, text: "\u{2026} (truncated)")]
        }
        return out
    }
}
