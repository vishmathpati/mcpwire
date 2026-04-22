import fs from 'node:fs'
import { parse as parseToml } from 'smol-toml'
import { parse as parseYaml } from 'yaml'

// Server entry shape returned by all readers
export interface ServerEntry {
  name: string
  transport: 'stdio' | 'http' | 'sse'
  command?: string
  args?: string[]
  url?: string
}

// Strip JSONC comments (same as merger.ts)
function stripComments(src: string): string {
  let out = ''
  let i = 0
  let inString = false
  while (i < src.length) {
    const ch = src[i]!
    if (ch === '"' && (i === 0 || src[i - 1] !== '\\')) { inString = !inString; out += ch; i++; continue }
    if (!inString) {
      if (ch === '/' && src[i + 1] === '/') { while (i < src.length && src[i] !== '\n') i++; continue }
      if (ch === '/' && src[i + 1] === '*') { i += 2; while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i++; i += 2; continue }
    }
    out += ch; i++
  }
  return out
}

function rawToEntry(name: string, raw: Record<string, unknown>): ServerEntry {
  const hasUrl = typeof raw['url'] === 'string'
  const transport = hasUrl
    ? ((raw['type'] === 'sse' ? 'sse' : 'http') as 'http' | 'sse')
    : 'stdio'

  const entry: ServerEntry = { name, transport }
  if (transport === 'stdio') {
    entry.command = raw['command'] as string | undefined
    entry.args = raw['args'] as string[] | undefined
  } else {
    entry.url = raw['url'] as string
  }
  return entry
}

// Read from a JSON file that uses mcpServers / servers / context_servers key
export function readJsonServers(filePath: string, key: string): ServerEntry[] {
  if (!fs.existsSync(filePath)) return []
  try {
    const raw = fs.readFileSync(filePath, 'utf-8')
    const data = JSON.parse(stripComments(raw)) as Record<string, unknown>

    // Zed uses nested command wrapper; others are flat
    const map = data[key] as Record<string, unknown> | undefined
    if (!map || typeof map !== 'object') return []

    return Object.entries(map).map(([name, val]) => {
      const v = val as Record<string, unknown>
      // Zed wraps command: { path, args }
      if (v['command'] && typeof v['command'] === 'object') {
        const cmd = v['command'] as Record<string, unknown>
        return rawToEntry(name, { command: cmd['path'], args: cmd['args'] })
      }
      return rawToEntry(name, v)
    })
  } catch {
    return []
  }
}

// Read from Continue's YAML (mcpServers is an array)
export function readYamlServers(filePath: string): ServerEntry[] {
  if (!fs.existsSync(filePath)) return []
  try {
    const raw = fs.readFileSync(filePath, 'utf-8')
    const data = parseYaml(raw) as Record<string, unknown>
    const arr = data['mcpServers']
    if (!Array.isArray(arr)) return []
    return arr.map((entry: Record<string, unknown>) =>
      rawToEntry((entry['name'] as string) ?? 'unknown', entry)
    )
  } catch {
    return []
  }
}

// Read from Codex TOML ([mcp_servers.<name>])
export function readTomlServers(filePath: string): ServerEntry[] {
  if (!fs.existsSync(filePath)) return []
  try {
    const raw = fs.readFileSync(filePath, 'utf-8')
    const data = parseToml(raw) as Record<string, unknown>
    const table = data['mcp_servers'] as Record<string, unknown> | undefined
    if (!table) return []
    return Object.entries(table).map(([name, val]) =>
      rawToEntry(name, val as Record<string, unknown>)
    )
  } catch {
    return []
  }
}
