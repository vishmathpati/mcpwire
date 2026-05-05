# docs/INDEX.md — Project Hub
> Two sections: human map + agent dependency index.
> Update Section 1 when pages change. Update Section 2 when features/data/services change.

---

## Section 1 — Human Map

**Project:** Project Hub — native macOS menu bar app for managing AI coding tool configs across projects.
**Stack:** Swift + SwiftUI + AppKit, macOS 14+. No external dependencies.
**Build:** `swift build` inside `projecthub/`. Run: `swift run`.

**Views:**

| View | What it shows | Features |
|------|--------------|---------|
| Popover (480×680) | Main menu bar panel, 4 tabs | Entry point for all features |
| Projects tab | List of tracked project folders | Add projects, auto-discover, open in Finder, drill into detail |
| Skills tab (global) | All skills across Claude/Codex/Cursor | Browse global library, see install counts per project |
| MCP tab (global) | All MCP servers across 12 AI tools | Search, import, edit, copy between tools, enable/disable |
| Settings tab | App preferences | [VERIFY — minimal implementation] |
| Project Detail | Per-project sub-tabs | 6 sub-tabs: Skills, Agents, MCP, Rules, Hooks, CLAUDE.md |
| Live Mode panel | Floating always-on-top context window monitor | Real-time token usage, skill/MCP toggles |
| Dashboard window | Full expanded NSWindow | [VERIFY — exists in DashboardWindow.swift] |

**Features:**

| Feature | View | Status |
|---------|------|--------|
| Project auto-discovery (Claude, Codex, filesystem) | Projects tab | live |
| Project detail drill-in (6 sub-tabs) | ProjectDetailView | live |
| Profile copy across projects | CopyProfileSheet | live |
| Global skill library browser | Skills tab | live |
| Per-project skill install/remove/edit | ProjectDetail › Skills | live |
| Per-project Claude sub-agent create/delete | ProjectDetail › Agents | live |
| Global MCP server manager | MCP tab | live |
| Per-project MCP config view/edit | ProjectDetail › MCP | live |
| Per-project Cursor rules CRUD | ProjectDetail › Rules | live |
| Per-project hooks viewer (read-only) | ProjectDetail › Hooks | live |
| Per-project CLAUDE.md editor with templates | ProjectDetail › CLAUDE.md | live |
| Live Mode context monitoring | LiveModeView / BeaconView | in-progress [VERIFY] |

---

## Section 2 — Agent Dependency Index

### Data Model

| Entity | File | Purpose |
|--------|------|---------|
| `Project` | Models.swift | User-added project: UUID, path, displayName, addedAt, lastOpenedAt |
| `DiscoveredProject` | Models.swift | Auto-found project before user adds it: path, sources set, tool IDs |
| `Skill` | Models.swift | Global skill: name, description, triggers, source (Claude/Codex/Cursor), directory path |
| `InstalledSkill` | Models.swift | Skill installed in a project: optional claude + codex paths |
| `Agent` | Models.swift | Claude sub-agent: name, description, model, tools list, markdown body, file path |
| `MCPServerInfo` | Models.swift | Project-scoped server: source (claude-code/codex/cursor), name, detail string |
| `ServerEntry` | Models.swift | Global MCP server: transport, command/args or URL, disabled flag |
| `ToolSummary` | Models.swift | One AI tool's server list: toolID, servers `[ServerEntry]` |
| `HookEntry` | HooksView.swift | One hook: tool name, event, command, matcher, scope |
| `CursorRule` | CursorRulesView.swift | One .mdc rule: description, globs, alwaysApply, filename, body |
| `ContextSnapshot` | ContextEstimator.swift | Live Mode: full token estimate for a project |

**Persistence:**
- `[Project]` → `UserDefaults` key `projecthub.projects.v1` (JSON-encoded)
- All other data is read live from filesystem on demand — no local database

### External Services

| Service | What for | Access |
|---------|---------|--------|
| Claude Code session files | Live Mode token counting | Direct filesystem: `~/.claude/projects/<encoded>/*.jsonl` |
| Claude Code config | Project discovery, global MCP | Direct filesystem: `~/.claude.json` |
| Codex SQLite | Project discovery | Direct filesystem: `~/.codex/state_N.sqlite` — `SELECT cwd FROM threads` |
| Codex config | Project detection, MCP | Direct filesystem: `~/.codex/config.toml` (regex-parsed) |
| macOS `lsof` | Live Mode active-project detection | Shell command: `lsof -F pn -d cwd -c claude` |

No network calls. No external APIs. All data is local filesystem only.

### Key Files

| File | Why it matters |
|------|---------------|
| `Core/ConfigWriter.swift` | Central to ALL MCP writes across all 12 tools — any MCP feature touches this |
| `Stores/ProjectStore.swift` | Project list persistence + 3-source auto-discovery — all project-aware features depend on this |
| `LiveMode/ContextEstimator.swift` | Token counting logic for Live Mode — reads JSONL session files + skill dirs |
| `LiveMode/ProjectWatcher.swift` | Active project detection — polls `~/.claude/projects/` + `lsof` every 2 seconds |
| `Core/FullConfigReader.swift` | Reads ALL tool configs for the global MCP tab — slow operation, cached |
| `Models.swift` | All shared data types — change here breaks everything |

### Critical Functions / Components

| Function | File | Used by |
|----------|------|---------|
| `ProjectStore.scan()` | ProjectStore.swift | Projects tab, menu bar refresh, app open |
| `ProjectStore.detectedTools(at:)` | ProjectStore.swift | Project row badges, `makeProject()` |
| `ConfigWriter.writeServer(toolID:scope:projectRoot:name:config:)` | ConfigWriter.swift | MCPStore.copyServer, MCPStore.replaceServerConfig, MCPEditServerSheet |
| `ConfigWriter.removeServer(toolID:scope:projectRoot:name:)` | ConfigWriter.swift | MCPView, GlobalMCPView, MCPStore |
| `ConfigWriter.disableServer / enableServer` | ConfigWriter.swift | MCPStore.toggleServerDisabled, LiveModeView.toggleMCP |
| `SkillReader.scanSkillDir(_:source:)` | SkillReader.swift | SkillStore global scan, ContextEstimator |
| `ContextEstimator.estimate(for:)` | ContextEstimator.swift | LiveModeView.refreshSnapshot |
| `ProjectWatcher.pollActiveProject()` | ProjectWatcher.swift | LiveModeView (onChange) |
| `ProfileCopier` (class) | Core/ProfileCopier.swift | CopyProfileSheet — copies skills + agents + rules |

### Feature Dependency Map

```
projects-tab:
  flow: ProjectsView → ProjectStore.scan() → [claude.json, Codex SQLite, filesystem]
  data: Project (UserDefaults), DiscoveredProject (ephemeral)
  guards: reads user home dir; requires filesystem access
  shared with: project-detail (all sub-tabs)

skills-global:
  flow: GlobalSkillsView → SkillStore.refresh() → SkillReader.scanSkillDir() → [~/.claude/skills/, ~/.codex/skills/, ~/.cursor/skills-cursor/]
  data: Skill (in-memory)
  guards: none
  shared with: skills-per-project (install copies dirs), live-mode (skill tokens)

mcp-global:
  flow: GlobalMCPView → MCPStore.refresh() → FullConfigReader.readAllTools() → [all 12 tool config files]
  data: ToolSummary → [ServerEntry]
  guards: reads ~/Library/Application Support, ~/.config paths
  shared with: mcp-per-project (ConfigWriter), live-mode (MCP toggle)

agents-per-project:
  flow: AgentsView → AgentStore → AgentReader.agents(at:) → <project>/.claude/agents/*.md
  data: Agent (parsed frontmatter + body)
  guards: none
  shared with: (none)

hooks-per-project:
  flow: HooksView → HooksReader.hooks(for:) → [<project>/.claude/settings.json, .codex/config.toml, .cursor/settings.json]
  data: HookEntry (read-only)
  guards: read-only; no writes
  shared with: (none)

claude-md-per-project:
  flow: ClaudeMdView → ClaudeMdReader.read/write(at:) → <project>/CLAUDE.md
  data: raw string
  guards: creates file if missing; overwrites on save
  shared with: (none)

cursor-rules-per-project:
  flow: CursorRulesView → CursorRulesReader → <project>/.cursor/rules/*.mdc
  data: CursorRule (frontmatter + body)
  guards: creates .cursor/rules/ if missing
  shared with: profile-copy (ProfileCopier copies rules)

profile-copy:
  flow: CopyProfileSheet → ProfileCopier.copy(from:to:) → bulk copy of skills + agents + rules dirs
  data: (no new models — copies existing files)
  guards: destructive if target already has same-named files; shows preview
  shared with: skills-per-project, agents-per-project, cursor-rules-per-project

live-mode:
  flow: LiveModeView → ProjectWatcher (2s poll) → ContextEstimator.estimate() → [~/.claude/projects/<enc>/*.jsonl, skill dirs, ~/.claude.json]
  data: ContextSnapshot (ephemeral, never persisted)
  guards: lsof call may be slow; JSONL scan reads last assistant message only
  shared with: mcp-global (ConfigWriter for enable/disable), skills (SkillReader for counts)
  → docs/detail/live-mode.md [VERIFY — consider creating if Live Mode has complex flow]
```

### Guardrails

1. **ConfigWriter is the only thing that writes MCP configs.** Never write `.mcp.json`, `.cursor/mcp.json`, or `.codex/config.toml` directly from a view — always go through `ConfigWriter`. It handles backup rotation.
2. **ProjectStore is the source of truth for the project list.** Never read `UserDefaults` for projects directly — always use `ProjectStore`.
3. **Live Mode must not block the main thread.** `ContextEstimator.estimate()` and `ProjectWatcher.pollActiveProject()` are async — do not call them synchronously.
4. **All file reads are from the user's home directory.** No sandboxing bypass needed; the app reads `~/.claude/`, `~/.codex/`, `~/.cursor/`, `~/Library/Application Support/`. Respect these paths exactly.
5. **No network calls anywhere in the app.** If a new feature requires a network call, surface it to the user for decision — it's a policy change.
