import { CopyButton } from "./CopyButton";

const BREW_CMD = "brew install --cask vishmathpati/mcpbolt/mcpboltbar";
const GITHUB_URL = "https://github.com/vishmathpati/mcpbolt";
const DOWNLOAD_URL = `${GITHUB_URL}/releases/latest`;

const features = [
  {
    icon: "⚡",
    title: "One‑click install",
    body: "Add a server to Claude, Cursor, VS Code, Windsurf, Zed, and more in a single action. No JSON editing.",
  },
  {
    icon: "🔁",
    title: "Sync across apps",
    body: "Copy a server to every other tool. MCPBolt handles the per‑app config shape for you.",
  },
  {
    icon: "🗑️",
    title: "Remove from everywhere",
    body: "Uninstall a server from every tool at once, or just one. You're always in control.",
  },
  {
    icon: "✏️",
    title: "Edit in place",
    body: "Change command, args, and env with a real form. No terminal, no backslash escaping.",
  },
  {
    icon: "🚦",
    title: "Live health checks",
    body: "Green, amber, red. See which servers are installed, reachable, or broken — at a glance.",
  },
  {
    icon: "🔄",
    title: "Restart host apps",
    body: "After a config change MCPBolt can relaunch Claude, Cursor, or VS Code so changes take effect.",
  },
  {
    icon: "📦",
    title: "Import from URL",
    body: "Paste a link to a JSON config, preview it, then apply to any supported app.",
  },
  {
    icon: "🗂️",
    title: "Projects tab",
    body: "Manage per‑repo MCP configs. Add a folder, switch between global and project‑scoped servers in one place.",
  },
  {
    icon: "🔍",
    title: "Auto‑discovery",
    body: "MCPBolt scans your Mac for Claude Code and Codex CLI projects automatically — no manual setup needed.",
  },
  {
    icon: "📊",
    title: "Coverage matrix",
    body: "See every server side‑by‑side across all your tools. Gaps in coverage are obvious at a glance.",
  },
  {
    icon: "👀",
    title: "Diff preview",
    body: "See exactly which lines change before you commit. No surprise writes to your config files.",
  },
  {
    icon: "↩️",
    title: "Undo last change",
    body: "Every write makes a timestamped backup. One click restores the previous state.",
  },
  {
    icon: "🖥️",
    title: "Full‑screen dashboard",
    body: "Expand beyond the menu bar popover into a resizable window with sidebar navigation.",
  },
  {
    icon: "🚀",
    title: "Launch at login",
    body: "Optional. Starts in the menu bar and stays out of your way.",
  },
];

const compat = [
  { name: "Claude Desktop", dot: "#d97757" },
  { name: "Cursor", dot: "#000000" },
  { name: "VS Code", dot: "#1e88e5" },
  { name: "Windsurf", dot: "#009688" },
  { name: "Zed", dot: "#084ccf" },
  { name: "Claude Code", dot: "#d97757" },
  { name: "Codex CLI", dot: "#10a37f" },
  { name: "opencode", dot: "#8b5cf6" },
  { name: "Roo", dot: "#e91e63" },
  { name: "Gemini CLI", dot: "#4285f4" },
];

const security = [
  {
    title: "Atomic writes",
    body: "Config files are written atomically. If the disk dies mid‑write, the old file is still intact.",
  },
  {
    title: "Timestamped backups",
    body: "Every edit keeps the last three backups per file. Older .bak files rotate out automatically.",
  },
  {
    title: "Local‑only",
    body: "MCPBolt never phones home. No telemetry, no account, no cloud. It edits files on your disk and nothing else.",
  },
  {
    title: "Open source",
    body: "MIT licensed. Read the code, build it yourself, fork it. Trust by inspection.",
  },
];

export default function Page() {
  return (
    <>
      {/* Nav */}
      <nav className="nav">
        <div className="container nav-inner">
          <a href="#top" className="logo">
            <span className="logo-mark"><span className="logo-bolt">⚡</span></span>
            <span>MCPBolt</span>
          </a>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#compat">Works with</a>
            <a href="#security">Security</a>
            <a href={GITHUB_URL} className="nav-cta" target="_blank" rel="noreferrer">GitHub</a>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <header id="top" className="hero container">
        <div className="tag">
          <span className="tag-dot" />
          <span>v0.5.8 — Projects, auto‑discovery & Codex CLI</span>
        </div>
        <h1>
          One‑click MCP servers<br />
          <span className="accent">for every app</span>
        </h1>
        <p className="sub">
          A tiny menu bar app that installs, syncs, and manages Model Context Protocol servers
          across Claude Desktop, Cursor, VS Code, Windsurf, Zed, and more. Local. Free. Open source.
        </p>
        <div className="cta-row">
          <a href={DOWNLOAD_URL} className="btn btn-primary" target="_blank" rel="noreferrer">
            Download for macOS
          </a>
          <a href={GITHUB_URL} className="btn" target="_blank" rel="noreferrer">
            View source ↗
          </a>
        </div>
        <div className="meta-line">
          macOS 14+ · Apple Silicon and Intel · <a href={GITHUB_URL}>MIT licensed</a>
        </div>
      </header>

      {/* Brew */}
      <div className="brew">
        <div className="brew-panel">
          <div className="brew-code mono">
            <span className="prompt">$</span>
            {BREW_CMD}
          </div>
          <CopyButton text={BREW_CMD} />
        </div>
      </div>

      {/* Screenshot (simulated dashboard) */}
      <div className="shot-wrap container">
        <div className="shot-card" style={{ maxWidth: 640 }}>
          <div className="shot-header">
            <div className="bolt-round">⚡</div>
            <div className="shot-title">mcpbolt</div>
            <div style={{ flex: 1 }} />
            <div className="pill">5 apps · 8 servers</div>
          </div>
          {/* Tab bar */}
          <div style={{ display: "flex", gap: 6, padding: "8px 12px", borderBottom: "1px solid rgba(255,255,255,0.08)" }}>
            {["By App", "Coverage", "Projects", "Settings"].map((t, i) => (
              <div key={t} style={{
                padding: "4px 12px", borderRadius: 20, fontSize: 11, fontWeight: 600,
                background: i === 0 ? "linear-gradient(135deg,#f4c01e,#e8a000)" : "rgba(255,255,255,0.07)",
                color: i === 0 ? "#111" : "rgba(255,255,255,0.55)"
              }}>{t}</div>
            ))}
          </div>
          <div className="shot-body">
            <div className="tool-card">
              <div className="tool-icon" style={{ background: "#d97757" }}>C</div>
              <div className="tool-meta">
                <div className="tool-name">Claude Desktop</div>
                <div className="tool-sub">3 servers · healthy</div>
              </div>
              <div className="tool-count">3</div>
            </div>
            <div className="tool-card">
              <div className="tool-icon" style={{ background: "#111" }}>⌘</div>
              <div className="tool-meta">
                <div className="tool-name">Cursor</div>
                <div className="tool-sub">2 servers · 1 needs auth</div>
              </div>
              <div className="tool-count">2</div>
            </div>
            <div className="tool-card">
              <div className="tool-icon" style={{ background: "#1e88e5" }}>VS</div>
              <div className="tool-meta">
                <div className="tool-name">VS Code</div>
                <div className="tool-sub">1 server · healthy</div>
              </div>
              <div className="tool-count">1</div>
            </div>
            <div className="tool-card">
              <div className="tool-icon" style={{ background: "#10a37f" }}>✦</div>
              <div className="tool-meta">
                <div className="tool-name">Codex CLI</div>
                <div className="tool-sub">2 servers · healthy</div>
              </div>
              <div className="tool-count">2</div>
            </div>
            <div className="tool-card">
              <div className="tool-icon" style={{ background: "#084ccf" }}>Z</div>
              <div className="tool-meta">
                <div className="tool-name">Zed</div>
                <div className="tool-sub">1 server · healthy</div>
              </div>
              <div className="tool-count">1</div>
            </div>
          </div>
        </div>
      </div>

      {/* Features */}
      <section id="features" className="block">
        <div className="container">
          <div className="section-head">
            <div className="section-kicker">Features</div>
            <h2>Everything you'd want, nothing you wouldn't</h2>
            <p>MCPBolt does one job. It writes the right JSON to the right file, every time, across every app.</p>
          </div>
          <div className="feature-grid">
            {features.map((f) => (
              <div key={f.title} className="feature">
                <div className="feature-icon">{f.icon}</div>
                <h3>{f.title}</h3>
                <p>{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Compat */}
      <section id="compat" className="block">
        <div className="container">
          <div className="section-head">
            <div className="section-kicker">Works with</div>
            <h2>Every major MCP client</h2>
            <p>Native apps, editor extensions, CLIs. Config shape translation is handled automatically.</p>
          </div>
          <div className="compat-row">
            {compat.map((c) => (
              <div key={c.name} className="compat-chip">
                <span className="compat-dot" style={{ background: c.dot }} />
                <span>{c.name}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Security */}
      <section id="security" className="block">
        <div className="container">
          <div className="section-head">
            <div className="section-kicker">Security</div>
            <h2>Your config is yours</h2>
            <p>MCPBolt runs entirely on your machine. No server, no account, no data leaves your disk.</p>
          </div>
          <div className="security-grid">
            {security.map((s) => (
              <div key={s.title} className="sec-card">
                <h3><span className="check">✓</span> {s.title}</h3>
                <p>{s.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer>
        <div className="container">
          <div className="foot-links">
            <a href={GITHUB_URL} target="_blank" rel="noreferrer">GitHub</a>
            <a href={`${GITHUB_URL}/issues`} target="_blank" rel="noreferrer">Issues</a>
            <a href={`${GITHUB_URL}/releases`} target="_blank" rel="noreferrer">Releases</a>
            <a href={`${GITHUB_URL}/blob/main/LICENSE`} target="_blank" rel="noreferrer">License</a>
          </div>
          <div>Built by <a href={GITHUB_URL}>@vishmathpati</a> · MIT licensed · macOS 14+</div>
        </div>
      </footer>
    </>
  );
}
