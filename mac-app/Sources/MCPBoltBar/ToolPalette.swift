import SwiftUI
import AppKit

// MARK: - Per-tool visual identity (color + SF Symbol)

struct ToolPalette {
    struct Entry {
        let color: Color
        let icon:  String   // SF Symbol name
    }

    static let map: [String: Entry] = [
        "claude-desktop": Entry(
            color: Color(red: 0.84, green: 0.38, blue: 0.38),
            icon:  "bubble.left.and.bubble.right.fill"
        ),
        "claude-code": Entry(
            color: Color(red: 0.74, green: 0.27, blue: 0.27),
            icon:  "terminal.fill"
        ),
        "cursor": Entry(
            color: Color(red: 0.54, green: 0.34, blue: 0.96),
            icon:  "cursorarrow.rays"
        ),
        "vscode": Entry(
            color: Color(red: 0.02, green: 0.47, blue: 0.87),
            icon:  "chevron.left.forwardslash.chevron.right"
        ),
        "codex": Entry(
            color: Color(red: 0.20, green: 0.76, blue: 0.44),
            icon:  "sparkles"
        ),
        "windsurf": Entry(
            color: Color(red: 0.06, green: 0.72, blue: 0.60),
            icon:  "wind"
        ),
        "zed": Entry(
            color: Color(red: 0.53, green: 0.19, blue: 0.90),
            icon:  "bolt.circle.fill"
        ),
        "continue": Entry(
            color: Color(red: 0.18, green: 0.78, blue: 0.43),
            icon:  "arrow.clockwise"
        ),
        "gemini": Entry(
            color: Color(red: 0.25, green: 0.54, blue: 0.98),
            icon:  "sparkle"
        ),
        "roo": Entry(
            color: Color(red: 0.98, green: 0.44, blue: 0.10),
            icon:  "antenna.radiowaves.left.and.right"
        ),
        "opencode": Entry(
            color: Color(red: 0.92, green: 0.58, blue: 0.16),
            icon:  "curlybraces"
        ),
        "cline": Entry(
            color: Color(red: 0.13, green: 0.65, blue: 0.82),
            icon:  "scroll.fill"
        ),
    ]

    static func color(for toolID: String) -> Color {
        map[toolID]?.color ?? Color.accentColor
    }

    static func icon(for toolID: String) -> String {
        map[toolID]?.icon ?? "app.fill"
    }

    // Returns the real app icon from NSWorkspace if the app is installed,
    // nil for CLI-only tools or apps that aren't present on this Mac.
    static func appImage(for toolID: String) -> NSImage? {
        let candidates: [String: [String]] = [
            "claude-desktop": ["/Applications/Claude.app"],
            "cursor":         ["/Applications/Cursor.app"],
            "vscode":         ["/Applications/Visual Studio Code.app",
                               "/Applications/VSCode.app"],
            "windsurf":       ["/Applications/Windsurf.app"],
            "zed":            ["/Applications/Zed.app", "/Applications/Zed Preview.app"],
            "roo":            ["/Applications/Roo.app"],
            "continue":       ["/Applications/Continue.app"],
            "cline":          ["/Applications/Cline.app"],
        ]
        guard let paths = candidates[toolID] else { return nil }
        let fm = FileManager.default
        for path in paths {
            if fm.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        return nil
    }
}
