import AppKit
import Foundation

// MARK: - Restart the host app of a given MCP tool so it picks up config changes.
// Only tools that ship as a macOS .app are restartable. CLI tools (claude-code,
// codex, gemini, opencode) and editor extensions (cline, roo, continue) return
// .notRestartable and surface manual instructions in the UI.

@MainActor
enum AppRestart {

    enum Result {
        case restarted(name: String)
        case notRunning(name: String)
        case notRestartable(hint: String)
        case failed(message: String)
    }

    /// Returns the bundle id of the host app for a tool id, if any.
    static func bundleID(for toolID: String) -> String? {
        switch toolID {
        case "claude-desktop": return "com.anthropic.claudefordesktop"
        case "cursor":         return "com.todesktop.230313mzl4w4u92"
        case "vscode":         return "com.microsoft.VSCode"
        case "windsurf":       return "com.exafunction.windsurf"
        case "zed":            return "dev.zed.Zed"
        default:               return nil
        }
    }

    /// Friendly display name for the host app.
    static func displayName(for toolID: String) -> String {
        switch toolID {
        case "claude-desktop": return "Claude"
        case "cursor":         return "Cursor"
        case "vscode":         return "Visual Studio Code"
        case "windsurf":       return "Windsurf"
        case "zed":            return "Zed"
        default:               return toolID
        }
    }

    /// Hint to show for CLI tools and editor extensions that have no .app to restart.
    static func manualHint(for toolID: String) -> String {
        switch toolID {
        case "claude-code": return "Exit and re-run `claude` in your terminal."
        case "codex":       return "Exit and re-run `codex` in your terminal."
        case "gemini":      return "Exit and re-run `gemini` in your terminal."
        case "opencode":    return "Exit and re-run `opencode` in your terminal."
        case "cline", "roo", "continue":
            return "Reload VS Code (Cmd+Shift+P → \"Developer: Reload Window\")."
        default:
            return "Restart the host app to pick up the change."
        }
    }

    /// Is there a running instance of the app for this tool?
    static func isRunning(toolID: String) -> Bool {
        guard let bid = bundleID(for: toolID) else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bid).isEmpty == false
    }

    /// Quits the app gracefully (sending .terminate), waits up to ~4s for it
    /// to exit, then relaunches. Returns a Result you can surface to the UI.
    static func restart(toolID: String) async -> Result {
        guard let bid = bundleID(for: toolID) else {
            return .notRestartable(hint: manualHint(for: toolID))
        }

        let name = displayName(for: toolID)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bid)

        if running.isEmpty {
            return .notRunning(name: name)
        }

        // Resolve the app URL before terminating so we can relaunch.
        let appURL = running.first?.bundleURL
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)

        for app in running {
            _ = app.terminate()
        }

        // Poll for exit.
        let deadline = Date().addingTimeInterval(4.0)
        while Date() < deadline {
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
            if stillRunning.isEmpty { break }
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }

        guard let appURL else {
            return .failed(message: "Couldn't find \(name) to relaunch.")
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            return .restarted(name: name)
        } catch {
            return .failed(message: "Couldn't relaunch \(name): \(error.localizedDescription)")
        }
    }
}
