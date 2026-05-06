import Foundation
import AppKit

// MARK: - Config reader

final class ConfigReader {
    static let shared = ConfigReader()
    private init() {}

    private let home = FileManager.default.homeDirectoryForCurrentUser.path
    private let cwd  = FileManager.default.currentDirectoryPath
    private let fm   = FileManager.default

    // Read every tool and return summaries (called off the main thread)
    func readAllTools() -> [ToolSummary] {
        ALL_TOOL_META.map { meta in
            let (detected, servers) = readTool(id: meta.id)
            return ToolSummary(
                toolID:   meta.id,
                label:    meta.label,
                short:    meta.short,
                detected: detected,
                servers:  servers
            )
        }
    }

    // MARK: - Per-tool dispatch

    private func readTool(id: String) -> (detected: Bool, servers: [ServerEntry]) {
        switch id {

        case "claude-desktop":
            let dir  = "\(home)/Library/Application Support/Claude"
            let path = "\(dir)/claude_desktop_config.json"
            let detected = fm.fileExists(atPath: dir) || appExists("com.anthropic.claudefordesktop")
            var servers = readJsonServers(path: path, key: "mcpServers")
            // DXT extensions installed via Claude Desktop's official registry
            let dxt = readDxtExtensions()
            servers = mergeDeduped(primary: servers, secondary: dxt)
            return (detected, servers)

        case "claude-code":
            let primaryPath = "\(home)/.claude.json"
            let detected = onPath("claude") || fm.fileExists(atPath: primaryPath)
            // Merge all three global MCP sources; first-wins dedup
            var servers = readJsonServers(path: primaryPath, key: "mcpServers")
            servers = mergeDeduped(primary: servers,
                                   secondary: readJsonServers(path: "\(home)/.claude/settings.json", key: "mcpServers"))
            servers = mergeDeduped(primary: servers,
                                   secondary: readJsonServers(path: "\(home)/.claude/mcp.json", key: "mcpServers"))
            // Plugin-bundled MCPs (read-only)
            let plugins = readClaudeCodePlugins()
            servers = mergeDeduped(primary: servers, secondary: plugins)
            return (detected, servers)

        case "cursor":
            let path = "\(home)/.cursor/mcp.json"
            return (fm.fileExists(atPath: "\(home)/.cursor") || appExists("com.todesktop.230313mzl4w4u92"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "vscode":
            let path = "\(home)/Library/Application Support/Code/User/mcp.json"
            return (onPath("code") || appExists("com.microsoft.VSCode"),
                    readJsonServers(path: path, key: "servers"))

        case "codex":
            let path = "\(home)/.codex/config.toml"
            let detected = onPath("codex") || fm.fileExists(atPath: "\(home)/.codex")
            var servers = readTomlServers(path: path)
            let plugins = readCodexPlugins(configPath: path)
            servers = mergeDeduped(primary: servers, secondary: plugins)
            return (detected, servers)

        case "windsurf":
            let path = "\(home)/.codeium/windsurf/mcp_config.json"
            return (fm.fileExists(atPath: "\(home)/.codeium/windsurf") || appExists("com.codeium.windsurf"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "zed":
            let path = "\(home)/.config/zed/settings.json"
            return (fm.fileExists(atPath: "\(home)/.config/zed") || appExists("dev.zed.Zed"),
                    readJsonNestedServers(path: path, keys: ["context_servers"]))

        case "continue":
            let path = "\(home)/.continue/config.yaml"
            return (fm.fileExists(atPath: "\(home)/.continue"),
                    readYamlServers(path: path))

        case "gemini":
            let path = "\(home)/.gemini/settings.json"
            return (onPath("gemini") || fm.fileExists(atPath: "\(home)/.gemini"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "roo":
            let path = "\(cwd)/.roo/mcp.json"
            return (fm.fileExists(atPath: "\(cwd)/.roo"),
                    readJsonServers(path: path, key: "mcpServers"))

        case "opencode":
            let path = "\(home)/.config/opencode/opencode.json"
            return (onPath("opencode") || fm.fileExists(atPath: "\(home)/.config/opencode"),
                    readJsonServers(path: path, key: "mcp"))

        case "cline":
            let path = "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
            return (fm.fileExists(atPath: path) ||
                    fm.fileExists(atPath: "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev"),
                    readJsonServers(path: path, key: "mcpServers"))

        default:
            return (false, [])
        }
    }

    // MARK: - Merge / dedup helpers

    // First-wins dedup: primary entries take precedence over secondary on name collision.
    private func mergeDeduped(primary: [ServerEntry], secondary: [ServerEntry]) -> [ServerEntry] {
        var seen = Set(primary.map { $0.name })
        var result = primary
        for s in secondary where !seen.contains(s.name) {
            seen.insert(s.name)
            result.append(s)
        }
        return result
    }

    // MARK: - Auth detection

    private let credKeys = ["KEY", "TOKEN", "SECRET", "PASSWORD", "AUTH", "CREDENTIAL"]

    private func detectAuth(env: [String: String]?, headers: [String: String]?, note: String?) -> (needsAuth: Bool, oauthNote: String?) {
        if let env = env {
            let hasCredKey = env.keys.contains { k in
                credKeys.contains { k.uppercased().contains($0) }
            }
            if hasCredKey { return (true, nil) }
        }
        if let headers = headers {
            let hasAuth = headers.values.contains { $0.hasPrefix("Bearer") || $0.contains("${") }
            if hasAuth { return (true, nil) }
        }
        if let note = note, note.lowercased().contains("oauth") {
            return (true, note)
        }
        return (false, nil)
    }

    // MARK: - JSON / JSONC

    private func readJsonServers(path: String, key: String, source: String = "manual", readonly: Bool = false) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let stripped = stripJsonComments(raw)
        guard
            let data = stripped.data(using: .utf8),
            let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var result: [ServerEntry] = []
        if let dict = obj[key] as? [String: Any] {
            result += parseServerDict(dict, isDisabled: false, source: source, readonly: readonly)
        }
        if let disabled = obj["\(key)_disabled"] as? [String: Any] {
            result += parseServerDict(disabled, isDisabled: true, source: source, readonly: readonly)
        }
        return result.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func readJsonNestedServers(path: String, keys: [String]) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let stripped = stripJsonComments(raw)
        guard
            let data = stripped.data(using: .utf8),
            var obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        for key in keys.dropLast() {
            guard let next = obj[key] as? [String: Any] else { return [] }
            obj = next
        }
        guard let lastKey = keys.last, let dict = obj[lastKey] as? [String: Any] else { return [] }
        return parseServerDict(dict)
    }

    private func parseServerDict(
        _ dict: [String: Any],
        isDisabled: Bool = false,
        source: String = "manual",
        readonly: Bool = false
    ) -> [ServerEntry] {
        dict.compactMap { name, value in
            guard let props = value as? [String: Any] else { return nil }
            let command   = props["command"] as? String
            let args      = (props["args"] as? [String]) ?? []
            let url       = props["url"] as? String
            let env       = props["env"] as? [String: String]
            let headers   = props["headers"] as? [String: String]
            let note      = props["note"] as? String
            let transport: String
            if let t = props["type"] as? String { transport = t }
            else if url != nil { transport = "http" }
            else { transport = "stdio" }
            let (needsAuth, oauthNote) = detectAuth(env: env, headers: headers, note: note)
            var entry = ServerEntry(
                name: name,
                transport: transport,
                command: command,
                args: args,
                url: url,
                isDisabled: isDisabled
            )
            entry.source    = source
            entry.readonly  = readonly
            entry.needsAuth = needsAuth
            entry.oauthNote = oauthNote
            return entry
        }
    }

    // Parse a .mcp.json file — handles both wrapped { mcpServers: {...} } and flat { name: {...} }
    private func parseMcpJsonFile(path: String, source: String, readonly: Bool) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let stripped = stripJsonComments(raw)
        guard
            let data = stripped.data(using: .utf8),
            let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        // Try wrapped format first
        if let wrapped = obj["mcpServers"] as? [String: Any] {
            return parseServerDict(wrapped, source: source, readonly: readonly)
        }

        // Flat format: every value that has command or url is a server
        let flat = obj.filter { _, val in
            guard let props = val as? [String: Any] else { return false }
            return props["command"] is String || props["url"] is String
        }
        return parseServerDict(flat, source: source, readonly: readonly)
    }

    // MARK: - Claude Code plugins

    private func readClaudeCodePlugins() -> [ServerEntry] {
        let registryPath = "\(home)/.claude/plugins/installed_plugins.json"
        let settingsPath = "\(home)/.claude/settings.json"
        guard fm.fileExists(atPath: registryPath) else { return [] }

        // Load enabled/disabled state
        var enabledPlugins: [String: Bool] = [:]
        if let raw = try? String(contentsOfFile: settingsPath, encoding: .utf8),
           let stripped = Optional(stripJsonComments(raw)),
           let data = stripped.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ep = obj["enabledPlugins"] as? [String: Bool] {
            enabledPlugins = ep
        }

        guard
            let raw = try? Data(contentsOf: URL(fileURLWithPath: registryPath)),
            let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            let plugins = obj["plugins"] as? [String: [[String: Any]]]
        else { return [] }

        var servers: [ServerEntry] = []
        for (pluginKey, installs) in plugins {
            if enabledPlugins[pluginKey] == false { continue }
            // Prefer user-scoped install
            let install = installs.first(where: { ($0["scope"] as? String) == "user" }) ?? installs.first
            guard let installPath = install?["installPath"] as? String else { continue }
            let mcpPath = "\(installPath)/.mcp.json"
            servers += parseMcpJsonFile(path: mcpPath, source: "plugin", readonly: true)
        }
        return servers
    }

    // MARK: - Codex plugins

    private func readCodexPlugins(configPath: String) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }

        // Parse enabled plugins from TOML: [plugins."name@marketplace"] enabled = true
        var enabledPlugins: [(name: String, marketplace: String)] = []
        for line in raw.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[plugins.\"") && t.hasSuffix("\"]") {
                let key = String(t.dropFirst(10).dropLast(2))
                let parts = key.split(separator: "@", maxSplits: 1)
                if parts.count == 2 { enabledPlugins.append((String(parts[0]), String(parts[1]))) }
            }
        }

        // Check enabled = false for each plugin block
        var disabledKeys = Set<String>()
        var currentKey: String? = nil
        for line in raw.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[plugins.\"") && t.hasSuffix("\"]") {
                currentKey = String(t.dropFirst(10).dropLast(2))
            } else if t == "enabled = false", let key = currentKey {
                disabledKeys.insert(key)
            } else if t.hasPrefix("[") {
                currentKey = nil
            }
        }

        let cacheBase = "\(home)/.codex/plugins/cache"
        var servers: [ServerEntry] = []

        for (pluginName, marketplace) in enabledPlugins {
            let key = "\(pluginName)@\(marketplace)"
            if disabledKeys.contains(key) { continue }

            let pluginBaseDir = "\(cacheBase)/\(marketplace)/\(pluginName)"
            guard fm.fileExists(atPath: pluginBaseDir) else { continue }

            // Pick any version directory that has a .mcp.json
            guard let versions = try? fm.contentsOfDirectory(atPath: pluginBaseDir) else { continue }
            for version in versions {
                let mcpPath = "\(pluginBaseDir)/\(version)/.mcp.json"
                if fm.fileExists(atPath: mcpPath) {
                    servers += parseMcpJsonFile(path: mcpPath, source: "plugin", readonly: true)
                    break
                }
            }
        }

        return servers
    }

    // MARK: - Claude Desktop DXT extensions

    private func readDxtExtensions() -> [ServerEntry] {
        let registryPath = "\(home)/Library/Application Support/Claude/extensions-installations.json"
        let extBase      = "\(home)/Library/Application Support/Claude/Claude Extensions"
        let settingsBase = "\(home)/Library/Application Support/Claude/Claude Extensions Settings"

        guard
            fm.fileExists(atPath: registryPath),
            let raw = try? Data(contentsOf: URL(fileURLWithPath: registryPath)),
            let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            let extensions = obj["extensions"] as? [String: [String: Any]]
        else { return [] }

        var servers: [ServerEntry] = []

        for (extID, install) in extensions {
            // Read settings: enabled state + user config
            var isEnabled = true
            var userConfig: [String: Any] = [:]
            let settingsPath = "\(settingsBase)/\(extID).json"
            if let sRaw = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
               let sObj = try? JSONSerialization.jsonObject(with: sRaw) as? [String: Any] {
                isEnabled = sObj["isEnabled"] as? Bool ?? true
                userConfig = sObj["userConfig"] as? [String: Any] ?? [:]
            }
            guard isEnabled else { continue }

            guard
                let manifest = install["manifest"] as? [String: Any],
                let server   = manifest["server"] as? [String: Any],
                let mcpCfg   = server["mcp_config"] as? [String: Any]
            else { continue }

            let displayName = (manifest["display_name"] as? String)
                           ?? (manifest["name"] as? String)
                           ?? extID
            let command  = mcpCfg["command"] as? String
            let rawArgs  = mcpCfg["args"] as? [String] ?? []
            let env      = mcpCfg["env"] as? [String: String]
            let extDir   = "\(extBase)/\(extID)"

            // Resolve template variables in args
            let resolvedArgs = rawArgs.map { arg -> String in
                var s = arg
                s = s.replacingOccurrences(of: "${__dirname}", with: extDir)
                s = s.replacingOccurrences(of: "${HOME}", with: home)
                s = s.replacingOccurrences(of: "${DOCUMENTS}", with: "\(home)/Documents")
                // ${user_config.field}
                let pattern = #"\$\{user_config\.([^}]+)\}"#
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let nsStr = s as NSString
                    let matches = regex.matches(in: s, range: NSRange(location: 0, length: nsStr.length))
                    for m in matches.reversed() {
                        let fieldRange = m.range(at: 1)
                        let field = nsStr.substring(with: fieldRange)
                        let val: String
                        if let arr = userConfig[field] as? [String] {
                            val = arr.joined(separator: " ")
                        } else if let v = userConfig[field] {
                            val = "\(v)"
                        } else {
                            val = ""
                        }
                        s = (s as NSString).replacingCharacters(in: m.range, with: val)
                    }
                }
                return s
            }

            let (needsAuth, oauthNote) = detectAuth(env: env, headers: nil, note: nil)
            var entry = ServerEntry(
                name: displayName,
                transport: "stdio",
                command: command,
                args: resolvedArgs,
                url: nil,
                isDisabled: false
            )
            entry.source    = "extension"
            entry.readonly  = true
            entry.needsAuth = needsAuth
            entry.oauthNote = oauthNote
            servers.append(entry)
        }

        return servers
    }

    // MARK: - TOML (Codex: [mcp_servers.name] sections)

    private func readTomlServers(path: String) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return parseTomlMcpServers(raw)
    }

    private func parseTomlMcpServers(_ content: String) -> [ServerEntry] {
        var servers: [ServerEntry] = []
        var currentName: String?
        var props: [String: Any] = [:]

        func flush() {
            guard let name = currentName else { return }
            let command   = props["command"] as? String
            let args      = props["args"] as? [String] ?? []
            let url       = props["url"] as? String
            let env       = props["env"] as? [String: String]
            let transport: String
            if let t = props["type"] as? String { transport = t }
            else if url != nil { transport = "http" }
            else { transport = "stdio" }
            let isDisabled = (props["enabled"] as? String) == "false"
            let (needsAuth, oauthNote) = detectAuth(env: env, headers: nil, note: nil)
            var entry = ServerEntry(
                name: name,
                transport: transport,
                command: command,
                args: args,
                url: url,
                isDisabled: isDisabled
            )
            entry.needsAuth = needsAuth
            entry.oauthNote = oauthNote
            servers.append(entry)
            props = [:]
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // [mcp_servers.name]
            if trimmed.hasPrefix("[mcp_servers.") && trimmed.hasSuffix("]") && !trimmed.hasPrefix("[[") {
                flush()
                currentName = String(trimmed.dropFirst(13).dropLast())
                continue
            }

            if trimmed.hasPrefix("[") { continue } // other section

            // key = value
            guard let eqRange = trimmed.range(of: " = ") ?? trimmed.range(of: "=") else { continue }
            let key    = String(trimmed[trimmed.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rawVal = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            if rawVal.hasPrefix("[") {
                let inner = rawVal.dropFirst().dropLast()
                let items = inner.components(separatedBy: ",").map {
                    $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }.filter { !$0.isEmpty }
                props[key] = items
            } else if (rawVal.hasPrefix("\"") && rawVal.hasSuffix("\"")) ||
                      (rawVal.hasPrefix("'") && rawVal.hasSuffix("'")) {
                props[key] = String(rawVal.dropFirst().dropLast())
            } else {
                props[key] = rawVal
            }
        }

        flush()
        return servers.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - YAML (Continue: mcpServers array)

    private func readYamlServers(path: String) -> [ServerEntry] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return parseYamlMcpServers(raw)
    }

    private func parseYamlMcpServers(_ content: String) -> [ServerEntry] {
        var servers: [ServerEntry] = []
        var inBlock  = false
        var inItem   = false
        var props: [String: Any] = [:]

        func flush() {
            guard inItem, let name = props["name"] as? String else { return }
            let command   = props["command"] as? String
            let args      = props["args"] as? [String] ?? []
            let url       = props["url"] as? String
            let transport = url != nil ? "http" : "stdio"
            servers.append(ServerEntry(name: name, transport: transport, command: command, args: args, url: url))
            props = [:]; inItem = false
        }

        for line in content.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            if line == "mcpServers:" || line.hasPrefix("mcpServers:") {
                inBlock = true; continue
            }

            guard inBlock else { continue }

            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                flush(); break
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- ") {
                flush()
                inItem = true
                let rest = String(trimmed.dropFirst(2))
                parseYamlKeyVal(rest, into: &props)
            } else if inItem {
                parseYamlKeyVal(trimmed, into: &props)
            }
        }

        flush()
        return servers.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func parseYamlKeyVal(_ s: String, into props: inout [String: Any]) {
        guard let colonRange = s.range(of: ": ") else { return }
        let key    = String(s[s.startIndex..<colonRange.lowerBound])
        let rawVal = String(s[colonRange.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if rawVal.hasPrefix("[") {
            let inner = rawVal.dropFirst().dropLast()
            let items = inner.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }.filter { !$0.isEmpty }
            props[key] = items
        } else {
            props[key] = rawVal
        }
    }

    // MARK: - JSONC comment stripper

    private func stripJsonComments(_ src: String) -> String {
        var out = ""
        var i = src.startIndex
        var inString = false

        while i < src.endIndex {
            let ch = src[i]

            if ch == "\"" {
                let prev = i > src.startIndex ? src[src.index(before: i)] : Character("\0")
                if prev != "\\" { inString = !inString }
                out.append(ch); i = src.index(after: i); continue
            }

            if !inString {
                let next = src.index(after: i)
                if ch == "/" && next < src.endIndex {
                    if src[next] == "/" {
                        while i < src.endIndex && src[i] != "\n" { i = src.index(after: i) }
                        continue
                    }
                    if src[next] == "*" {
                        i = src.index(i, offsetBy: 2)
                        while i < src.endIndex {
                            if src[i] == "*" {
                                let n2 = src.index(after: i)
                                if n2 < src.endIndex && src[n2] == "/" { i = src.index(after: n2); break }
                            }
                            i = src.index(after: i)
                        }
                        continue
                    }
                }
            }

            out.append(ch); i = src.index(after: i)
        }
        return out
    }

    // MARK: - Detection helpers

    private func appExists(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    private func onPath(_ cmd: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = [cmd]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = pipe
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
