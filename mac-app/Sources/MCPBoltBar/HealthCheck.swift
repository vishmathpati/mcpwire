import Foundation

// MARK: - Basic reachability check for an MCP server entry.
// For stdio servers: resolve the command on PATH (which) — we don't actually
// spawn the server because it would pop terminals / prompt for OAuth / cost
// rate limit. For http/sse: HEAD the URL with a 4s timeout; 2xx/3xx/4xx
// all count as "something is there" (MCP endpoints often 401 on HEAD).
// 5xx and network failure count as red.

enum HealthStatus: Equatable {
    case ok(detail: String)       // green
    case warn(detail: String)     // yellow (e.g. unauthorized but reachable)
    case fail(detail: String)     // red
    case unknown                  // not yet checked
}

enum HealthCheck {

    static func check(_ s: ServerEntry) async -> HealthStatus {
        if s.transport == "stdio" {
            return checkStdio(s)
        }
        return await checkRemote(s)
    }

    // Resolve the first command on PATH. We also allow absolute paths.
    private static func checkStdio(_ s: ServerEntry) -> HealthStatus {
        guard let cmd = s.command, !cmd.isEmpty else {
            return .fail(detail: "No command defined")
        }

        // Absolute path — just file-exists + executable check.
        if cmd.hasPrefix("/") {
            let fm = FileManager.default
            if fm.isExecutableFile(atPath: cmd) { return .ok(detail: "Executable found") }
            return .fail(detail: "File not executable: \(cmd)")
        }

        // which <cmd>
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = [cmd]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = pipe
        do { try p.run() } catch {
            return .fail(detail: "Couldn't run `which`: \(error.localizedDescription)")
        }
        p.waitUntilExit()
        if p.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let resolved = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? cmd
            return .ok(detail: "Found at \(resolved)")
        }
        // Common installers aren't on GUI-app PATH even when the tool is
        // installed (npx via nvm is the usual culprit). We flag it warn, not
        // fail, so the user can investigate without panic.
        if ["npx", "uvx", "uv", "bunx", "pnpx"].contains(cmd) {
            return .warn(detail: "`\(cmd)` isn't on the app's PATH. Install it globally or use an absolute path.")
        }
        return .fail(detail: "Not found on PATH: \(cmd)")
    }

    private static func checkRemote(_ s: ServerEntry) async -> HealthStatus {
        guard let urlStr = s.url, let url = URL(string: urlStr) else {
            return .fail(detail: "Invalid URL")
        }

        var req = URLRequest(url: url, timeoutInterval: 4.0)
        req.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return .warn(detail: "Non-HTTP response")
            }
            switch http.statusCode {
            case 200...299:  return .ok(detail: "HTTP \(http.statusCode)")
            case 300...399:  return .ok(detail: "HTTP \(http.statusCode) (redirect)")
            case 401, 403:   return .warn(detail: "HTTP \(http.statusCode) — reachable, needs auth")
            case 400...499:  return .warn(detail: "HTTP \(http.statusCode)")
            default:         return .fail(detail: "HTTP \(http.statusCode)")
            }
        } catch {
            return .fail(detail: error.localizedDescription)
        }
    }
}
