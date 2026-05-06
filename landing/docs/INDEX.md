# docs/INDEX.md — mcpbolt-landing
> Two sections: human map + agent dependency index.

---

## Section 1 — Human Map

**Project:** mcpbolt.app — marketing + documentation website for mcpbolt.
**Stack:** Next.js 16, React 19, TypeScript, pure CSS.
**Dev:** `npm run dev`. Build: `npm run build`. Domain: `mcpbolt.app`.

**Pages:**

| Route | What it shows | Status |
|-------|--------------|--------|
| `/` | Home — hero, features, install block, compatibility grid, security callout | live |
| `/features` | Detailed feature breakdown | live |
| `/pricing` | CLI (free) vs Mac app ($29 lifetime) | live [VERIFY accuracy] |
| `/compare` | mcpbolt vs competitors + hand-editing | live |
| `/download` | Mac app download + install instructions | live |
| `/blog` | Blog post grid (7 posts) | live |
| `/blog/[slug]` | Individual blog post | live |
| `/changelog` | Version history | live [VERIFY content populated] |
| `/docs` | Docs landing page | live |
| `/docs/quickstart` | Quick start guide | live |
| `/docs/install` | Mac app install | live |
| `/docs/install-local` | Local MCP server setup | live |
| `/docs/install-streamable` | Streamable HTTP MCP setup | live |
| `/docs/cli` | CLI reference | live |
| `/docs/config-formats` | Supported config formats | live |
| `/docs/menubar` | Mac app usage guide | live |
| `/docs/projects` | Projects tab guide | live |
| `/docs/health` | Health check feature | live |
| `/docs/apps` | Supported apps list | live |
| `/docs/security` | Security/privacy page | live |
| `/docs/faq` | Frequently asked questions | live |
| `/docs/troubleshooting` | Troubleshooting guide | live |
| `/docs/windows` | Windows setup guide | live |
| `/tools` | Tools hub (converter + validator) | live |
| `/tools/converter` | Interactive MCP config converter | live |
| `/tools/validator` | MCP config validator | live |
| `/privacy` | Privacy policy | live |
| `/terms` | Terms of service | live |

**Blog posts** (`app/blog/content/`):
- introducing-mcpbolt, mcp-config-hell, what-is-mcp, top-mcp-servers-2026, mcp-security-red-flags, local-first-why-it-matters, mcp-windows-guide, mcp-tool-comparison, mcp-market-landscape

---

## Section 2 — Agent Dependency Index

### Data Model

No database. All content is static TypeScript files.

| Content type | File(s) | How to add |
|-------------|---------|-----------|
| Blog posts | `app/blog/content/*.tsx` + `app/blog/posts.ts` | Create new .tsx, add to posts.ts registry |
| Blog content registry | `app/blog/content/index.ts` + `app/blog/content.ts` | Export map of slug → component |
| Site metadata | `app/lib/site.ts` | Edit site name, description, OG tags |

### External Services

| Service | What for | Access |
|---------|---------|--------|
| Google Analytics | Page tracking | GA tag `G-GJK1E9W9L7` in `app/layout.tsx` via `<Script>` |

No auth, no database, no backend API routes.

### Key Files

| File | Why it matters |
|------|---------------|
| `app/globals.css` | The ENTIRE design system — all CSS variables, all component styles. If something looks wrong, it's here. |
| `app/layout.tsx` | Root layout — nav, footer, metadata, GA script |
| `app/lib/site.ts` | Site-wide constants (name, domain, metadata) [VERIFY exists] |
| `app/components/SiteNav.tsx` | Global nav used on every page |
| `app/components/SiteFooter.tsx` | Global footer |
| `app/blog/posts.ts` | Blog post registry — add here when creating new posts |

### Critical Functions / Components

| Component | File | Used by |
|-----------|------|---------|
| `SiteNav` | `app/components/SiteNav.tsx` | `app/layout.tsx` → every page |
| `SiteFooter` | `app/components/SiteFooter.tsx` | `app/layout.tsx` → every page |
| `Callout` | `app/components/Callout.tsx` | All doc pages |
| `DocsPageNav` | `app/docs/DocsPageNav.tsx` | All docs pages (prev/next nav) |
| `DocsSidebar` | `app/docs/DocsSidebar.tsx` | All docs pages |
| `ConverterTool` | `app/tools/converter/ConverterTool.tsx` | `/tools/converter` |
| `ValidatorTool` | `app/tools/validator/ValidatorTool.tsx` | `/tools/validator` |
| `CopyButton` | `app/CopyButton.tsx` | Install code blocks throughout |

### Feature Dependency Map

```
blog:
  flow: /blog → posts.ts registry → content/*.tsx components → rendered MDX-style
  shared with: (none — self-contained)
  adding a post: create tsx in content/, export from content/index.ts, add to posts.ts

docs:
  flow: /docs/[page] → each page.tsx → DocsSidebar + DocsPageNav shared components
  shared with: SiteNav, SiteFooter, Callout, globals.css
  adding a doc page: create app/docs/[page]/page.tsx, add link to DocsSidebar nav

tools:
  flow: /tools → ConverterTool / ValidatorTool (React components, client-side only)
  guards: no server calls — all processing happens in browser

nav + footer:
  flow: app/layout.tsx → SiteNav + SiteFooter wraps every page
  shared with: ALL pages
  warning: changes here affect every single page
```

### Guardrails

1. **No hardcoded colors.** Every visual value must use a CSS variable from `globals.css`. Run grep for hardcoded hex before closing any UI task.
2. **Blog posts are TypeScript components**, not MDX. Add them to the `posts.ts` registry or they won't appear.
3. **SiteNav and SiteFooter are global.** A layout or CSS change in these affects every page. Screenshot before and after.
4. **No backend routes.** This is a static marketing site. If a feature requires server logic, discuss with the user first.
5. **`globals.css` is the design system.** Don't add component-level `<style>` tags or inline styles — add to globals.css with a clear class name.
