import Foundation

// MARK: - Data models

struct ServerEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let transport: String   // "stdio" | "http" | "sse"
    let command: String?
    let args: [String]
    let url: String?
    var isDisabled: Bool = false

    var detail: String {
        if transport == "stdio" {
            let parts = ([command] + args.map { Optional($0) }).compactMap { $0 }
            return parts.joined(separator: " ")
        }
        return url ?? ""
    }
}

struct ToolSummary: Identifiable {
    var id: String { toolID }
    let toolID: String
    let label: String
    let short: String       // 2-letter abbreviation for the coverage grid
    let detected: Bool
    var servers: [ServerEntry]
}

// MARK: - Tool registry (order = display order)

/// Tool IDs that are still fully supported (config read/write works) but are
/// hidden from all UI surfaces until they're ready for prime time.
let HIDDEN_TOOL_IDS: Set<String> = ["continue"]

let ALL_TOOL_META: [(id: String, label: String, short: String)] = [
    ("claude-desktop", "Claude Desktop", "CD"),
    ("claude-code",    "Claude Code",    "CC"),
    ("cursor",         "Cursor",         "Cu"),
    ("vscode",         "VS Code",        "VS"),
    ("codex",          "Codex",          "Cx"),
    ("windsurf",       "Windsurf",       "Wi"),
    ("zed",            "Zed",            "Ze"),
    ("continue",       "Continue",       "Co"),
    ("gemini",         "Gemini",         "Ge"),
    ("roo",            "Roo",            "Ro"),
    ("opencode",       "opencode",       "Oc"),
    ("cline",          "Cline",          "Cl"),
]
