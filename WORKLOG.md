# Worklog — cleared after each session.

[18:08] fixed: ImportParser now handles bare `npx`/`bunx` commands (Path 1c) — ImportParser.swift. Derives server name from package identifier, preserves all args. Wizard commands (npx pkg mcp add) still caught by isWizardCommand before reaching this path.
[18:35] fixed: parseCliAdd now handles flags in any order (before/after name) — ImportParser.swift. Fixes `claude mcp add --scope project --transport http`, `gemini mcp add -t http`, `codex mcp add --url` all parsing correctly. Added `opencode` to tool prefixes. Added `authCommand` error for `mcp auth`/`mcp login`/`mcp logout` commands with helpful runtime message.
