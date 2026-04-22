import AppKit
import Foundation

// MARK: - Central place for app-level actions (menu + right-click + buttons)

@MainActor
enum AppActions {

    // MARK: - Version + URLs

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static let repoURL     = URL(string: "https://github.com/vishmathpati/mcpbolt")!
    static let releasesURL = URL(string: "https://github.com/vishmathpati/mcpbolt/releases")!

    // MARK: - Actions

    static func quit() {
        NSApp.terminate(nil)
    }

    static func openRepo() {
        NSWorkspace.shared.open(repoURL)
    }

    static func openReleases() {
        NSWorkspace.shared.open(releasesURL)
    }

    static func about() {
        let alert = NSAlert()
        alert.messageText = "mcpbolt"
        alert.informativeText = """
        Version \(currentVersion)

        Manage MCP servers across your AI coding tools — Claude, Cursor, VS Code, Codex, and more — from one menu bar app.

        github.com/vishmathpati/mcpbolt
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open GitHub")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openRepo()
        }
    }

    /// Ask GitHub for the latest release. `silent=true` suppresses the
    /// "you're up to date" alert and any network-error alert — useful for
    /// the background check on launch.
    static func checkForUpdates(silent: Bool = false) {
        Task {
            let result = await UpdateChecker.check()
            await MainActor.run {
                switch result {
                case .upToDate(let v):
                    guard !silent else { return }
                    let alert = NSAlert()
                    alert.messageText = "You're up to date."
                    alert.informativeText = "mcpbolt \(v) is the latest release."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()

                case .updateAvailable(let current, let latest):
                    let alert = NSAlert()
                    alert.messageText = "Update available"
                    alert.informativeText = "mcpbolt \(latest) is out. You're on \(current).\n\nIf you installed via brew, run:\n  brew upgrade --cask mcpboltbar"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Open releases")
                    alert.addButton(withTitle: "Later")
                    NSApp.activate(ignoringOtherApps: true)
                    let r = alert.runModal()
                    if r == .alertFirstButtonReturn { openReleases() }

                case .failed(let err):
                    guard !silent else { return }
                    let alert = NSAlert()
                    alert.messageText = "Couldn't check for updates"
                    alert.informativeText = err
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                }
            }
        }
    }
}
