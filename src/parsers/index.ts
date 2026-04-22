import type { IR } from '../core/ir.ts'
import { parseJson } from './json.ts'
import { parseYaml } from './yaml.ts'
import { parseToml } from './toml.ts'
import { parseCommand } from './command.ts'
import { parseCliAdd } from './cli-add.ts'

export type ParseResult = {
  servers: IR[]
  detectedFormat: string
}

export function autoparse(input: string): ParseResult {
  const trimmed = input.trim()
  if (!trimmed) throw new Error('Empty input')

  // 1. CLI tool command: claude mcp add / cursor mcp add / etc.
  if (/mcp\s+add\s+/i.test(trimmed)) {
    const ir = parseCliAdd(trimmed)
    if (ir) return { servers: [ir], detectedFormat: 'CLI command (claude mcp add / cursor mcp add)' }
  }

  // 2. Try JSON
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      const servers = parseJson(trimmed)
      return { servers, detectedFormat: 'JSON (Claude Desktop / VS Code / Cursor / Zed)' }
    } catch {
      // fall through
    }
  }

  // 3. Try TOML
  if (trimmed.includes('[mcp_servers') || trimmed.match(/^\[[\w.]+\]/m)) {
    try {
      const servers = parseToml(trimmed)
      return { servers, detectedFormat: 'TOML (Codex)' }
    } catch {
      // fall through
    }
  }

  // 4. Try YAML
  if (trimmed.includes(':\n') || trimmed.includes(': ') || trimmed.startsWith('-')) {
    try {
      const servers = parseYaml(trimmed)
      return { servers, detectedFormat: 'YAML (Continue)' }
    } catch {
      // fall through
    }
  }

  // 5. npx / docker / uvx command or bare URL
  const fromCommand = parseCommand(trimmed)
  if (fromCommand) {
    const format = trimmed.startsWith('http') ? 'URL' : 'command string'
    return { servers: [fromCommand], detectedFormat: format }
  }

  throw new Error(
    'Could not parse input.\n  Accepted: JSON (mcpServers/servers), YAML, TOML, npx/docker command, URL, or "claude mcp add ..." command.'
  )
}
