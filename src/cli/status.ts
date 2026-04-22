import { ALL_TARGETS } from '../targets/index.ts'
import type { Scope } from '../targets/_base.ts'
import type { ServerEntry } from '../core/reader.ts'
import { c, section } from './display.ts'

type Row = {
  tool: string
  scope: Scope
  configPath: string
  servers: ServerEntry[]
  detected: boolean
}

export function runList(): void {
  console.log()
  console.log(c.bold('  mcpbolt list') + c.dim(' — MCP servers installed across your tools'))
  console.log()

  const rows: Row[] = []

  for (const target of ALL_TARGETS) {
    const detected = target.detect()
    for (const scope of target.scopes) {
      const servers = detected ? target.readServers(scope) : []
      rows.push({
        tool: `${target.company}  ${target.name}`,
        scope,
        configPath: target.configPath(scope),
        servers,
        detected,
      })
    }
  }

  // Collect all unique server names across all tools
  const allServerNames = [...new Set(rows.flatMap((r) => r.servers.map((s) => s.name)))]

  if (allServerNames.length === 0) {
    console.log(c.dim('  No MCP servers installed in any detected tool yet.'))
    console.log(c.dim('  Run mcpbolt to install one.'))
    console.log()
    return
  }

  // ── Per-tool view ──────────────────────────────────────────────────────────
  section('Installed servers by tool')
  console.log()

  for (const row of rows) {
    if (!row.detected) continue

    const label = `${c.bold(row.tool)} ${c.dim(`(${row.scope})`)}`
    console.log(`  ${label}`)
    console.log(c.dim(`  ${row.configPath}`))

    if (row.servers.length === 0) {
      console.log(c.dim('    — none'))
    } else {
      for (const s of row.servers) {
        const transport = c.cyan(s.transport.padEnd(5))
        const detail =
          s.transport === 'stdio'
            ? c.dim(`${s.command ?? ''} ${(s.args ?? []).join(' ')}`.trim())
            : c.dim(s.url ?? '')
        console.log(`    ${c.bold(s.name.padEnd(24))} ${transport}  ${detail}`)
      }
    }
    console.log()
  }

  // ── Cross-tool matrix ──────────────────────────────────────────────────────
  section('Server coverage matrix')
  console.log()

  // Build tool column headers (abbreviated)
  const detectedRows = rows.filter((r) => r.detected)
  const colWidth = 6
  const nameWidth = 26

  // Header row
  const header = allServerNames.length > 0
    ? '  ' + ' '.repeat(nameWidth) + detectedRows.map((r) => {
        const short = (r.tool.split('  ')[1] ?? r.tool).slice(0, colWidth - 1).padEnd(colWidth)
        return c.dim(short)
      }).join(' ')
    : ''

  if (header) console.log(header)
  console.log(c.dim('  ' + '─'.repeat(nameWidth + detectedRows.length * (colWidth + 1))))

  for (const serverName of allServerNames) {
    const namePart = ('  ' + serverName).padEnd(nameWidth + 2)
    const cols = detectedRows.map((row) => {
      const found = row.servers.some((s) => s.name === serverName)
      return (found ? c.green('✓') : c.dim('·')).padEnd(colWidth)
    }).join(' ')
    console.log(`${namePart} ${cols}`)
  }

  console.log()
  console.log(c.dim(`  ${allServerNames.length} server(s) across ${detectedRows.length} tool config(s)`))
  console.log()
}
