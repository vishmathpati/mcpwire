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

    // Returns the real app icon if the .app bundle is installed.
    // Uses Bundle to read CFBundleIconFile directly — more reliable than NSWorkspace.
    static func appImage(for toolID: String) -> NSImage? {
        let candidates: [String: [String]] = [
            "claude-desktop": ["/Applications/Claude.app"],
            "claude-code":    ["/Applications/Claude Code Tool Manager.app"],
            "cursor":         ["/Applications/Cursor.app",
                               NSString("~/Applications/Cursor.app").expandingTildeInPath],
            "vscode":         ["/Applications/Visual Studio Code.app",
                               "/Applications/VSCode.app"],
            "codex":          ["/Applications/Codex.app"],
            "windsurf":       ["/Applications/Windsurf.app"],
            "zed":            ["/Applications/Zed.app", "/Applications/Zed Preview.app"],
            "roo":            ["/Applications/Roo.app"],
            "continue":       ["/Applications/Continue.app"],
            "cline":          ["/Applications/Cline.app"],
            "opencode":       ["/Applications/OpenCode.app"],
            "gemini":         ["/Applications/Gemini.app",
                               "/Applications/Google Gemini.app"],
        ]
        guard let paths = candidates[toolID] else { return nil }
        let fm = FileManager.default
        for path in paths {
            guard fm.fileExists(atPath: path) else { continue }
            // Read icon directly from bundle — avoids NSWorkspace permission issues
            if let bundle = Bundle(path: path),
               let iconName = bundle.infoDictionary?["CFBundleIconFile"] as? String,
               let resourcePath = bundle.resourcePath {
                let icns = iconName.hasSuffix(".icns") ? iconName : "\(iconName).icns"
                if let img = NSImage(contentsOfFile: "\(resourcePath)/\(icns)") {
                    img.size = NSSize(width: 36, height: 36)
                    return img
                }
                // Some bundles store without extension
                if let img = NSImage(contentsOfFile: "\(resourcePath)/\(iconName)") {
                    img.size = NSSize(width: 36, height: 36)
                    return img
                }
            }
            // Fallback to NSWorkspace (still works for most apps)
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}
