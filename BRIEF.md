# BRIEF.md — Project Hub / mcpbolt
> Distilled decisions. The why behind every call.
> 500-line limit — when reached, create BRIEF-2.md and add pointer here.

---

## v1.0 — 2026-04-23 · Cowork (seeded from ROADMAP.md decisions)

### What we're building

mcpbolt: visual settings editor for AI coding tools. CLI is free/open-source. Mac app is $29 lifetime.
Project Hub: separate native Swift app that evolved out of mcpbolt's Projects tab — broader scope (skills, agents, hooks, CLAUDE.md, MCP) across projects.

### Tech stack — chosen

| Technology | Why |
|------------|-----|
| Swift + SwiftUI + AppKit | Native macOS feel; no Electron overhead; no external deps |
| TypeScript + Bun | Fast CLI toolchain for mcpbolt npm package |
| Next.js | Landing page; familiar stack |

### Tech stack — rejected

| Technology | Why rejected |
|------------|-------------|
| Electron / Tauri | Not native macOS; heavier; CCTM (competitor) already does this |
| React Native / Flutter | No justification for cross-platform — Mac-only by design |
| Cloud backend | Out of scope permanently — local-only is a core value |

### Architecture decisions

- **Closed source Mac app + open source CLI**: CLI = viral distribution + Claude Max eligibility; app = revenue
- **$29 lifetime, no team tier**: team = cloud = distraction; stay solo-developer-focused
- **mcpbolt:// URL scheme** (planned v0.4): install buttons travel in docs and READMEs — distribution moat
- **"Visual settings editor" positioning** (not "MCP manager"): broader pain, bigger TAM, room for Claude Code settings, Skills, Hooks

### Scope — in

- MCP server management across 12 AI tools
- Claude Code settings editor
- Skills manager
- Hooks visual editor
- Project Hub: per-project skill/agent/MCP/hooks/CLAUDE.md management

### Scope — out (permanent)

- Enterprise / SSO / audit log
- Team sharing / cloud sync
- Chat interface / AI inside the app
- Generic launcher features

### Open questions (2026-04-23)

- Payment processor: Lemon Squeezy vs Paddle?
- Free Homebrew cask stays or goes?
- Apple Developer account enrolled?
- Launch target date?

---

## v1.1 — 2026-05-05 · Claude Code (init-project session)

### Focus shift

**Decision:** Project Hub is now the primary product in this repo. mcpbolt CLI and MCPBoltBar are deprioritized.

**Why:** Project Hub has evolved into a broader, more valuable tool. It covers skills, agents, MCP, hooks, CLAUDE.md, cursor rules, and Live Mode — a superset of what MCPBoltBar does. Two separate apps with overlapping scope creates confusion; better to develop one strong product.

**How to apply:** New work goes into `projecthub/`. Don't touch `src/` or `mac-app/` unless specifically asked. Status.md tracks Project Hub state.

### Current feature state (verified from source code)

All features through projecthub ROADMAP v0.5 are shipped and live in source:
- Projects tab (auto-discovery + detail drill-in) ✅
- Global Skills tab ✅
- Global MCP tab ✅
- Per-project: Skills, Agents, MCP, Rules, Hooks, CLAUDE.md ✅
- Profile copy across projects ✅
- Live Mode (floating context panel) — in source, verify completeness

### Repo structure stays as monorepo for now

Both Project Hub and mcpbolt share this git repo. May be split into separate repos in the future. Decision deferred — not blocking.
