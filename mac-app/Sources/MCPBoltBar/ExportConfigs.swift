import AppKit
import Foundation

// MARK: - Export every detected tool's MCP config to a single JSON file.
// Used by the "Export / backup" menu action. Produces a human-readable bundle
// with one entry per tool: { toolID, path, raw }.

@MainActor
enum ExportConfigs {

    struct Payload: Codable {
        let exportedAt: String
        let appVersion: String
        let machine:    String
        let tools:      [ToolExport]
    }

    struct ToolExport: Codable {
        let toolID: String
        let label:  String
        let path:   String
        let found:  Bool
        // Raw file contents when we could read it. Stored as a String so both
        // JSON and non-JSON files round-trip exactly.
        let contents: String?
    }

    /// Shows a save panel, writes the bundle, opens the folder in Finder.
    static func exportViaSavePanel(tools: [ToolSummary]) {
        let panel = NSSavePanel()
        panel.title = "Export MCP configs"
        panel.allowedContentTypes = [.json]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmm"
        panel.nameFieldStringValue = "mcpbolt-export-\(df.string(from: Date())).json"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try writeBundle(tools: tools, to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't export"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    static func writeBundle(tools: [ToolSummary], to url: URL) throws {
        let fm = FileManager.default
        let exports: [ToolExport] = tools.map { t in
            guard let spec = ToolSpecs.spec(for: t.toolID) else {
                return ToolExport(toolID: t.toolID, label: t.label, path: "(unknown)", found: false, contents: nil)
            }
            let exists = fm.fileExists(atPath: spec.path)
            var contents: String? = nil
            if exists {
                contents = try? String(contentsOfFile: spec.path, encoding: .utf8)
            }
            return ToolExport(
                toolID: t.toolID,
                label:  t.label,
                path:   spec.path,
                found:  exists,
                contents: contents
            )
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let host    = Host.current().localizedName ?? "mac"

        let payload = Payload(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: version,
            machine:    host,
            tools:      exports
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(payload)
        try data.write(to: url, options: [.atomic])
    }
}
