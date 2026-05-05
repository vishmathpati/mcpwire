# DESIGN.md — mcpbolt (CLI + Mac App)
> This repo contains the CLI (`src/`) and Mac app (`mac-app/`) — no web UI.
> The landing page design system moved to active/mcpbolt-landing/DESIGN.md.

---

## mcpbolt CLI

No visual UI — terminal output only. Uses `@inquirer/prompts` for interactive prompts.
Design considerations: clear terminal output, good color coding for success/error/info states.

## MCPBoltBar (Mac App)

Native Swift + SwiftUI app. Follows macOS HIG — no custom CSS tokens.

- Light/dark mode: `NSApp.effectiveAppearance` — never hardcode colors
- Use semantic SwiftUI colors: `.primary`, `.secondary`, `.accentColor`, etc.
- Popover size: configurable (was 600pt, bumped to 720pt in v0.3)
- Standard macOS spacing (8pt grid)
- SF Pro system font — don't import custom fonts

For any visual work in `mac-app/`, match the existing SwiftUI code style.

## Landing page

→ See `active/mcpbolt-landing/DESIGN.md` for the full CSS token design system.
