# BRIEF.md — mcpbolt-landing
> Distilled decisions. The why behind every call.
> 500-line limit — when reached, create BRIEF-2.md and add pointer here.

---

## v1.0 — 2026-04-23 · Cowork (seeded from ROADMAP.md)

### What we're building

Marketing + documentation site for mcpbolt at mcpbolt.app. Covers: home/hero, blog, docs, tools (converter + validator), changelog, pricing, comparison, download, legal.

### Tech stack — chosen

| Technology | Why |
|------------|-----|
| Next.js 16 | SSR + static export, file-based routing, fast builds |
| React 19 | Concurrent features, hooks |
| Pure CSS (no Tailwind) | Full control; bespoke design token system in globals.css |

### Tech stack — rejected

| Technology | Why rejected |
|------------|-------------|
| Tailwind CSS | Class verbosity; preferred custom token system for this level of design control |
| MDX for blog | Blog posts are TypeScript components for full layout control |
| CMS | Unnecessary — posts are static TS files, no content team |

### Design decisions

- Dark theme only — golden accent (`#ffd34d`), near-black background (`#0a0a0b`)
- All visual values as CSS custom properties — see DESIGN.md
- No Tailwind — pure CSS with `.container` max-width constraint (1120px)
- Blog posts as TypeScript components in `app/blog/content/` — not MDX

### Scope — in

- Marketing pages (home, features, pricing, compare, download)
- Documentation (14 pages covering CLI + mac app)
- Blog (developer-focused articles)
- Interactive tools (converter, validator) — React components, no server
- Legal (privacy, terms)

### Scope — out (permanent)

- No user accounts or auth
- No backend API routes
- No CMS or database
- No Project Hub content (separate site when ready)

---

## v1.1 — 2026-05-05 · Claude Code (init-project session)

### Separation from mcpbolt repo

Landing page moved from `active/mcp/landing/` to its own repo at `active/mcpbolt-landing/` on 2026-05-05.

**Why:** cleaner separation of concerns — site has its own deploy pipeline, its own changelog, its own release cadence. mcpbolt CLI/app repo no longer needs to track Next.js dependencies.

### Items needed before Product Hunt launch (from ROADMAP.md §8)

- [ ] Comparison table vs CCTM + hand-editing
- [ ] Feature GIF/screenshots section
- [ ] FAQ block (especially "why $29 if CLI is free?")
- [ ] Trust block (local-only, atomic writes, notarized, open source CLI)
- [ ] Link to MCP/Skills directory (`/servers`, `/skills`) when ready
- [ ] Refund policy link in footer
