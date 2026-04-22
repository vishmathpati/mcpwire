import type { IR, Transport } from '../core/ir.ts'

// Parses CLI-style MCP add commands from any tool, e.g.:
//   claude mcp add context7 --transport http https://mcp.context7.com/mcp
//   claude mcp add filesystem --transport stdio npx -y @mcp/server-filesystem /tmp
//   claude mcp add mytool -e API_KEY=abc npx -y my-mcp-server
//   cursor mcp add context7 --transport http https://mcp.context7.com/mcp
//   codex mcp add context7 --transport http https://mcp.context7.com/mcp

export function parseCliAdd(input: string): IR | null {
  const tokens = shellSplit(input.trim())
  if (tokens.length === 0) return null

  let i = 0

  // Skip optional tool prefix: claude / cursor / codex / windsurf / etc.
  const toolPrefixes = ['claude', 'cursor', 'codex', 'windsurf', 'gemini', 'zed']
  if (toolPrefixes.includes(tokens[i]?.toLowerCase() ?? '')) i++

  // Must have "mcp add"
  if (tokens[i]?.toLowerCase() !== 'mcp') return null
  i++
  if (tokens[i]?.toLowerCase() !== 'add') return null
  i++

  // Next token is the server name
  const name = tokens[i]
  if (!name || name.startsWith('-')) return null
  i++

  // Parse flags
  let transport: Transport = 'stdio'
  const env: Record<string, string> = {}
  const headers: Record<string, string> = {}

  while (i < tokens.length) {
    const tok = tokens[i] ?? ''

    if (tok === '--transport' || tok === '-t') {
      const val = tokens[++i] ?? 'stdio'
      transport = (val === 'http' || val === 'sse' || val === 'stdio') ? val : 'stdio'
      i++
      continue
    }

    if (tok === '--env' || tok === '-e') {
      const kv = tokens[++i] ?? ''
      const eq = kv.indexOf('=')
      if (eq > 0) env[kv.slice(0, eq)] = kv.slice(eq + 1)
      i++
      continue
    }

    if (tok === '--header' || tok === '-H') {
      const kv = tokens[++i] ?? ''
      const eq = kv.indexOf('=')
      if (eq > 0) headers[kv.slice(0, eq)] = kv.slice(eq + 1)
      i++
      continue
    }

    // Skip unknown flags + their value
    if (tok.startsWith('--')) { i += 2; continue }
    if (tok.startsWith('-') && tok.length === 2) { i += 2; continue }

    break // reached the command / url
  }

  const rest = tokens.slice(i)
  if (rest.length === 0) return null

  const ir: IR = { name, transport }

  if (transport === 'http' || transport === 'sse') {
    ir.url = rest[0]
    if (Object.keys(headers).length > 0) ir.headers = headers
  } else {
    ir.command = rest[0]
    if (rest.length > 1) ir.args = rest.slice(1)
  }

  if (Object.keys(env).length > 0) ir.env = env

  return ir
}

// Minimal shell tokenizer — handles single/double quoted strings
function shellSplit(input: string): string[] {
  const tokens: string[] = []
  let current = ''
  let inSingle = false
  let inDouble = false

  for (let i = 0; i < input.length; i++) {
    const ch = input[i]!
    if (ch === "'" && !inDouble) { inSingle = !inSingle; continue }
    if (ch === '"' && !inSingle) { inDouble = !inDouble; continue }
    if (ch === ' ' && !inSingle && !inDouble) {
      if (current) { tokens.push(current); current = '' }
      continue
    }
    current += ch
  }
  if (current) tokens.push(current)
  return tokens
}
