import { ALL_TARGETS } from '../targets/index.ts'
import type { ServerEntry } from '../core/reader.ts'
import { c } from './display.ts'

// Two-letter abbreviation for each target (no truncation ambiguity)
const ABBR: Record<string, string> = {
  'claude-desktop': 'CD',
  'claude-code':    'CC',
  'cursor':         'CU',
  'vscode':         'VS',
  'codex':          'CX',
  'windsurf':       'WF',
  'zed':            'ZD',
  'continue':       'CT',
  'gemini':         'GM',
  'roo':            'RC',
}

type ToolSummary = {
  id: string
  label: string        // "Claude Desktop"
  abbr: string         // "CD"
  detected: boolean
  servers: ServerEntry[]  // merged across user+project scopes
}

export function runList(): void {
  console.log()
  console.log(c.bold('  mcpbolt list') + c.dim(' — MCP servers across your tools'))
  console.log()

  // Build one entry per logical tool (merge user + project server lists)
  const tools: ToolSummary[] = []
  for (const target of ALL_TARGETS) {
    const detected = target.detect()
    const merged: Map<string, ServerEntry> = new Map()
    if (detected) {
      for (const scope of target.scopes) {
        for (const s of target.readServers(scope)) {
          merged.set(s.name, s) // last scope wins (project overrides user if same name)
        }
      }
    }
    tools.push({
      id: target.id,
      label: target.name,
      abbr: ABBR[target.id] ?? target.id.slice(0, 2).toUpperCase(),
      detected,
      servers: [...merged.values()],
    })
  }

  const detectedTools = tools.filter(t => t.detected)
  const allServerNames = [...new Set(detectedTools.flatMap(t => t.servers.map(s => s.name)))]
    .sort((a, b) => {
      // Sort by how many tools have it (most common first)
      const aCount = detectedTools.filter(t => t.servers.some(s => s.name === a)).length
      const bCount = detectedTools.filter(t => t.servers.some(s => s.name === b)).length
      return bCount - aCount
    })

  if (allServerNames.length === 0) {
    console.log(c.dim('  No MCP servers installed in any detected tool yet.'))
    console.log(c.dim('  Run mcpbolt to install one.'))
    console.log()
    return
  }

  // ── Per-tool view ──────────────────────────────────────────────────────────
  console.log(c.bold('  Installed servers by tool'))
  console.log()

  for (const tool of detectedTools) {
    console.log(`  ${c.bold(tool.label)}`)

    if (tool.servers.length === 0) {
      console.log(c.dim('    — none'))
    } else {
      for (const s of tool.servers) {
        const transport = c.cyan(s.transport.padEnd(5))
        const detail = s.transport === 'stdio'
          ? c.dim(`${s.command ?? ''} ${(s.args ?? []).join(' ')}`.trim().slice(0, 60))
          : c.dim((s.url ?? '').slice(0, 60))
        console.log(`    ${s.name.padEnd(26)} ${transport}  ${detail}`)
      }
    }
    console.log()
  }

  // ── Coverage matrix ────────────────────────────────────────────────────────
  console.log(c.bold('  Server coverage matrix'))
  console.log()

  const COL = 4   // column width per tool
  const NAME_W = 28

  // Header: tool abbreviations
  const headerCols = detectedTools.map(t => c.dim(t.abbr.padEnd(COL))).join('')
  console.log('  ' + ' '.repeat(NAME_W) + headerCols)

  // Divider
  console.log(c.dim('  ' + '─'.repeat(NAME_W) + '─'.repeat(detectedTools.length * COL)))

  // Rows
  for (const serverName of allServerNames) {
    const name = serverName.length > NAME_W - 2
      ? serverName.slice(0, NAME_W - 3) + '…'
      : serverName
    const cols = detectedTools.map(tool => {
      const has = tool.servers.some(s => s.name === serverName)
      return (has ? c.green('✓') : c.dim('·')).padEnd(COL)
    }).join('')
    console.log(`  ${name.padEnd(NAME_W)}${cols}`)
  }

  // Legend
  console.log()
  console.log(c.dim('  Legend:'))
  const legendCols = detectedTools.map(t => `${c.bold(t.abbr)} ${t.label}`)
  // Print legend in rows of 4
  for (let i = 0; i < legendCols.length; i += 4) {
    console.log('  ' + legendCols.slice(i, i + 4).map(s => s.padEnd(28)).join('  '))
  }

  console.log()
  console.log(c.dim(`  ${allServerNames.length} servers  ·  ${detectedTools.length} tools detected`))
  console.log()
}
