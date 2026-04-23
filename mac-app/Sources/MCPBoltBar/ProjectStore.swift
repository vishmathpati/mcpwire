import Foundation
import AppKit
import SQLite3

// MARK: - Discovery source

enum DiscoverySource: Equatable, Hashable, CaseIterable {
    case claudeCode   // ~/.claude.json → projects
    case codexCLI     // ~/.codex/state_N.sqlite → threads.cwd
    case filesystem   // filesystem walk of ~/Projects, ~/Developer, etc.
}

// MARK: - Discovered project model

/// A project folder found by auto-scanning this Mac. Not persisted — rebuilt on each scan.
/// `sources` can contain multiple values when a project is found by more than one scanner
/// (e.g. a repo used in both Claude Code and Codex CLI).
struct DiscoveredProject: Identifiable, Equatable {
    let id: UUID
    let path: String
    let displayName: String
    let hasGit: Bool
    let detectedTools: [String]
    let sources: Set<DiscoverySource>

    /// The "primary" source for icon/color display — codex > claude > filesystem.
    var primarySource: DiscoverySource {
        if sources.contains(.codexCLI)   { return .codexCLI }
        if sources.contains(.claudeCode) { return .claudeCode }
        return .filesystem
    }

    /// Sources in a consistent display order (claude, codex, filesystem).
    var orderedSources: [DiscoverySource] {
        [.claudeCode, .codexCLI, .filesystem].filter { sources.contains($0) }
    }
}

// MARK: - Project model

/// A project folder the user has added to the Projects tab. Project-scope MCP
/// configs live under this folder at well-known paths:
///   - .cursor/mcp.json
///   - .vscode/mcp.json
///   - .roo/mcp.json
///   - .mcp.json (claude-code)
struct Project: Codable, Identifiable, Equatable {
    let id: UUID
    var path: String
    var displayName: String
    var addedAt: Date
    var lastOpenedAt: Date

    /// Canonicalises a raw path (resolves symlinks, strips trailing slash).
    /// Used for upsert-by-path so the same folder isn't added twice.
    static func canonicalize(_ raw: String) -> String {
        let expanded = (raw as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL.resolvingSymlinksInPath()
        return url.path
    }

    static func folderName(at path: String) -> String {
        (path as NSString).lastPathComponent
    }

    /// Is the folder still on disk? UI greys out "missing" projects.
    var exists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

// MARK: - Store

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects:   [Project] = []
    @Published private(set) var discovered: [DiscoveredProject] = []
    @Published private(set) var isScanning: Bool = false

    private let defaultsKey = "mcpbolt.projects.v1"

    init() {
        load()
        scan()
    }

    // MARK: - Public API

    /// Adds a folder to the recents list, or bumps its lastOpenedAt if it's
    /// already there. Returns the resulting Project.
    @discardableResult
    func add(path rawPath: String, displayName: String? = nil) -> Project {
        let path = Project.canonicalize(rawPath)
        if let idx = projects.firstIndex(where: { $0.path == path }) {
            projects[idx].lastOpenedAt = Date()
            if let name = displayName { projects[idx].displayName = name }
            sortAndPersist()
            return projects[idx]
        }
        let now = Date()
        let project = Project(
            id: UUID(),
            path: path,
            displayName: displayName ?? Project.folderName(at: path),
            addedAt: now,
            lastOpenedAt: now
        )
        projects.append(project)
        sortAndPersist()
        return project
    }

    func remove(id: UUID) {
        projects.removeAll { $0.id == id }
        persist()
    }

    func rename(id: UUID, to name: String) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        projects[idx].displayName = trimmed.isEmpty ? Project.folderName(at: projects[idx].path) : trimmed
        persist()
    }

    func touch(id: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].lastOpenedAt = Date()
        sortAndPersist()
    }

    /// Pops a folder picker. Returns the chosen path (canonical) or nil.
    func pickFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Add project folder"
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return Project.canonicalize(url.path)
    }

    // MARK: - Auto-discovery

    /// Background scan of common dev directories. Safe to call multiple times — no-ops if already scanning.
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        let existingPaths = Set(projects.map { $0.path })
        Task.detached(priority: .utility) { [weak self] in
            let found = ProjectStore.findProjects(excluding: existingPaths)
            await MainActor.run {
                self?.discovered = found
                self?.isScanning = false
            }
        }
    }

    /// Promotes a discovered project into the manually-tracked list and removes it from `discovered`.
    @discardableResult
    func addDiscovered(_ disc: DiscoveredProject) -> Project {
        let p = add(path: disc.path, displayName: disc.displayName)
        discovered.removeAll { $0.id == disc.id }
        return p
    }

    // MARK: - Background scan helpers (nonisolated — runs on Task.detached)

    /// Three-source discovery. Each scanner runs with only `existingPaths` excluded
    /// (already-added projects), NOT each other's results. This lets a project appear
    /// in multiple scanners (e.g. mysnapfinder in both claude.json AND codex sqlite).
    /// Results are merged by path, combining sources so the Codex tab shows it too.
    nonisolated private static func findProjects(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        let claudeFound      = fromClaudeJson(excluding: existingPaths)
        let codexFound       = fromCodexSqlite(excluding: existingPaths)
        let codexConfigFound = fromCodexConfig(excluding: existingPaths)
        let fsFound          = fromFilesystem(excluding: existingPaths)

        var byPath: [String: DiscoveredProject] = [:]
        for project in claudeFound + codexFound + codexConfigFound + fsFound {
            if let existing = byPath[project.path] {
                byPath[project.path] = DiscoveredProject(
                    id:            existing.id,
                    path:          existing.path,
                    displayName:   existing.displayName,
                    hasGit:        existing.hasGit || project.hasGit,
                    detectedTools: Array(Set(existing.detectedTools + project.detectedTools)).sorted(),
                    sources:       existing.sources.union(project.sources)
                )
            } else {
                byPath[project.path] = project
            }
        }

        return byPath.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Read all project paths from ~/.claude.json → `projects` dictionary.
    nonisolated private static func fromClaudeJson(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        var seen = existingPaths
        let fm   = FileManager.default
        let home = NSHomeDirectory()
        let claudeJsonPath = (home as NSString).appendingPathComponent(".claude.json")

        guard let data     = fm.contents(atPath: claudeJsonPath),
              let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any]
        else { return [] }

        var found: [DiscoveredProject] = []

        for rawPath in projects.keys {
            let canonical = Project.canonicalize(rawPath)
            guard !seen.contains(canonical) else { continue }

            // Skip git worktrees Claude Code creates automatically
            guard !canonical.contains("/.claude/worktrees/") else { continue }
            // Skip internal tool directories (Paperclip etc.)
            guard !canonical.contains("/.paperclip/") else { continue }
            // Skip root and home dir itself
            guard canonical != "/", canonical != home else { continue }
            // Must exist on disk as a directory
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: canonical, isDirectory: &isDir), isDir.boolValue else { continue }

            let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
            let tools  = detectedTools(at: canonical, fm: fm)

            found.append(DiscoveredProject(
                id:            UUID(),
                path:          canonical,
                displayName:   Project.folderName(at: canonical),
                hasGit:        hasGit,
                detectedTools: tools,
                sources:       [.claudeCode]
            ))
            seen.insert(canonical)
            if found.count >= 60 { break }
        }

        return found
    }

    /// Read ~/.codex/state_N.sqlite → threads.cwd to find every directory
    /// Codex CLI has ever worked in.
    nonisolated private static func fromCodexSqlite(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        var seen = existingPaths
        let fm   = FileManager.default
        let home = NSHomeDirectory()
        let codexDir = (home as NSString).appendingPathComponent(".codex")

        let dbPath = (1...9).reversed().lazy.compactMap { n -> String? in
            let p = (codexDir as NSString).appendingPathComponent("state_\(n).sqlite")
            return fm.fileExists(atPath: p) ? p : nil
        }.first
        guard let dbPath else { return [] }

        let broadPaths: Set<String> = [
            home, "/",
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Library"),
        ]

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let sql = "SELECT DISTINCT cwd FROM threads WHERE cwd IS NOT NULL AND cwd != '' AND cwd != '/'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let codexSessionDir = (home as NSString).appendingPathComponent("Documents/Codex")
        var found: [DiscoveredProject] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let ptr = sqlite3_column_text(stmt, 0) else { continue }
            let canonical = Project.canonicalize(String(cString: ptr))
            guard !seen.contains(canonical), !broadPaths.contains(canonical) else { continue }
            guard !canonical.hasPrefix(codexSessionDir) else { continue }
            let folderName = Project.folderName(at: canonical)
            let looksLikeSession = folderName.count > 10 &&
                folderName.prefix(4).allSatisfy(\.isNumber) &&
                folderName.dropFirst(4).hasPrefix("-")
            guard !looksLikeSession else { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: canonical, isDirectory: &isDir), isDir.boolValue else { continue }
            let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
            guard hasGit else { continue }
            let tools = detectedTools(at: canonical, fm: fm)
            found.append(DiscoveredProject(
                id: UUID(), path: canonical, displayName: folderName,
                hasGit: true, detectedTools: tools, sources: [.codexCLI]
            ))
            seen.insert(canonical)
            if found.count >= 40 { break }
        }
        return found
    }

    /// Read ~/.codex/config.toml → [projects."<path>"] keys.
    /// These are every project the user has explicitly trusted in Codex — a precise list.
    nonisolated private static func fromCodexConfig(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        let fm   = FileManager.default
        let home = NSHomeDirectory()
        let configPath = (home as NSString).appendingPathComponent(".codex/config.toml")

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }

        let broadPaths: Set<String> = [
            home, "/",
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Library"),
        ]

        // Match [projects."/path/to/folder"] TOML section headers
        guard let regex = try? NSRegularExpression(pattern: #"\[projects\."([^"]+)"\]"#) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        var seen = existingPaths
        var found: [DiscoveredProject] = []

        for match in matches {
            guard let pathRange = Range(match.range(at: 1), in: content) else { continue }
            let rawPath = String(content[pathRange])
            let canonical = Project.canonicalize(rawPath)

            guard !seen.contains(canonical) else { continue }
            guard !broadPaths.contains(canonical) else { continue }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: canonical, isDirectory: &isDir), isDir.boolValue else { continue }

            let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
            let tools  = detectedTools(at: canonical, fm: fm)

            found.append(DiscoveredProject(
                id:            UUID(),
                path:          canonical,
                displayName:   Project.folderName(at: canonical),
                hasGit:        hasGit,
                detectedTools: tools,
                sources:       [.codexCLI]
            ))
            seen.insert(canonical)
        }

        return found
    }

    /// Walk common dev roots for projects with a .git or MCP config that
    /// haven't been opened with Claude Code yet.
    nonisolated private static func fromFilesystem(excluding existingPaths: Set<String>) -> [DiscoveredProject] {
        var seen = existingPaths
        let fm   = FileManager.default
        let home = NSHomeDirectory()

        let rootNames = ["Projects", "Developer", "dev", "code", "src", "workspace", "Sites"]
        let roots = rootNames
            .map { (home as NSString).appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0) }

        let skip: Set<String> = [
            "node_modules", ".git", ".cache", "Library", ".Trash",
            "build", "dist", ".next", "vendor", ".npm", ".yarn",
            "DerivedData", ".gradle", "__pycache__"
        ]

        var found: [DiscoveredProject] = []

        for root in roots {
            guard let level1 = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for name in level1.sorted() {
                guard !name.hasPrefix("."), !skip.contains(name) else { continue }
                let path = (root as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }

                if let p = makeProject(at: path, excluding: seen, fm: fm) {
                    found.append(p); seen.insert(p.path)
                } else {
                    // Level 2 for org/company folders (~/Developer/acme/repo)
                    guard let level2 = try? fm.contentsOfDirectory(atPath: path) else { continue }
                    for name2 in level2.prefix(20) {
                        guard !name2.hasPrefix("."), !skip.contains(name2) else { continue }
                        let path2 = (path as NSString).appendingPathComponent(name2)
                        var isDir2: ObjCBool = false
                        guard fm.fileExists(atPath: path2, isDirectory: &isDir2), isDir2.boolValue else { continue }
                        if let p = makeProject(at: path2, excluding: seen, fm: fm) {
                            found.append(p); seen.insert(p.path)
                        }
                        if found.count >= 40 { break }
                    }
                }
                if found.count >= 40 { break }
            }
            if found.count >= 40 { break }
        }

        return found
    }

    nonisolated private static func makeProject(at path: String, excluding: Set<String>, fm: FileManager) -> DiscoveredProject? {
        let canonical = Project.canonicalize(path)
        guard !excluding.contains(canonical) else { return nil }

        let hasGit = fm.fileExists(atPath: (canonical as NSString).appendingPathComponent(".git"))
        let tools  = detectedTools(at: canonical, fm: fm)
        guard hasGit || !tools.isEmpty else { return nil }

        return DiscoveredProject(
            id:            UUID(),
            path:          canonical,
            displayName:   Project.folderName(at: canonical),
            hasGit:        hasGit,
            detectedTools: tools,
            sources:       [.filesystem]
        )
    }

    nonisolated private static func detectedTools(at path: String, fm: FileManager) -> [String] {
        let checks: [(String, String)] = [
            (".mcp.json",        "claude-code"),
            (".cursor/mcp.json", "cursor"),
            (".vscode/mcp.json", "vscode"),
            (".roo/mcp.json",    "roo"),
        ]
        return checks.compactMap { (rel, id) in
            fm.fileExists(atPath: (path as NSString).appendingPathComponent(rel)) ? id : nil
        }
    }

    /// Fast file-existence check: which project-scoped tools have configs in this folder.
    /// Used for tab filtering without full config parsing.
    func detectedToolIDs(for project: Project) -> [String] {
        ProjectStore.detectedTools(at: project.path, fm: FileManager.default)
    }

    // MARK: - Counts (for the landing list)

    struct ServerCount {
        let toolID: String
        let count: Int
    }

    /// For each project-scoped tool, returns how many servers its config lists
    /// in this project. Tools with no config file present are omitted.
    func counts(for project: Project) -> [ServerCount] {
        var out: [ServerCount] = []
        for toolID in ToolSpecs.projectScopedTools.sorted() {
            let servers = ConfigWriter.readAllServers(
                toolID: toolID,
                scope: .project,
                projectRoot: project.path
            )
            if !servers.isEmpty {
                out.append(ServerCount(toolID: toolID, count: servers.count))
            }
        }
        return out
    }

    /// Total servers across every project-scoped tool. Used for the "N" pill
    /// on the right side of each project row.
    func totalServerCount(for project: Project) -> Int {
        counts(for: project).reduce(0) { $0 + $1.count }
    }

    // MARK: - Persistence

    private func sortAndPersist() {
        projects.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        }
    }
}
