#!/usr/bin/env node
import { autoparse } from '../parsers/index.ts'
import { ALL_TARGETS } from '../targets/index.ts'
import {
  readPaste,
  promptServerName,
  promptTargets,
  promptEnvValues,
  promptDryRun,
  promptConfirm,
  promptContinueOnMultiple,
} from './prompts.ts'
import { banner, success, warn, info, hint, error, section, c } from './display.ts'
import { runList } from './status.ts'

// ── Subcommand routing ────────────────────────────────────────────────────────

const args = process.argv.slice(2)
const cmd = args[0]?.toLowerCase()

if (cmd === 'list' || cmd === 'status' || cmd === 'ls') {
  runList()
  process.exit(0)
}

if (cmd === '--help' || cmd === '-h' || cmd === 'help') {
  console.log()
  console.log(c.bold('  mcpbolt ⚡') + '  Wire any MCP server into every AI coding tool\n')
  console.log('  Usage:')
  console.log(c.cyan('    mcpbolt') + '              Interactive install — paste any MCP config')
  console.log(c.cyan('    mcpbolt list') + '         Show all installed MCP servers across tools')
  console.log(c.cyan('    mcpbolt --help') + '       Show this help\n')
  console.log('  Accepted input formats:')
  console.log(c.dim('    JSON (mcpServers / servers / context_servers)'))
  console.log(c.dim('    claude mcp add <name> --transport http <url>'))
  console.log(c.dim('    npx / docker / uvx command strings'))
  console.log(c.dim('    YAML (Continue), TOML (Codex), bare URL'))
  console.log()
  process.exit(0)
}

// ── Main install flow ─────────────────────────────────────────────────────────

async function main(): Promise<void> {
  banner()

  // 1. Read input
  const raw = await readPaste()
  if (!raw.trim()) {
    error('Nothing pasted. Exiting.')
    process.exit(1)
  }

  // 2. Parse
  let parsed
  try {
    parsed = autoparse(raw)
  } catch (e) {
    error((e as Error).message)
    process.exit(1)
  }

  section('Detected')
  info(`Format : ${c.cyan(parsed.detectedFormat)}`)
  info(`Servers : ${c.bold(String(parsed.servers.length))} — ${parsed.servers.map((s) => c.cyan(s.name)).join(', ')}`)

  // Show parsed details for CLI commands / URLs so user can verify
  const first = parsed.servers[0]
  if (first) {
    if (first.transport === 'stdio' && first.command) {
      info(`Command : ${c.dim(`${first.command} ${(first.args ?? []).join(' ')}`.trim())}`)
    } else if (first.url) {
      info(`URL     : ${c.dim(first.url)}`)
    }
  }

  // 3. If multiple servers, pick one
  let ir = await promptContinueOnMultiple(parsed.servers)

  // 4. Allow rename
  const confirmedName = await promptServerName(ir.name)
  ir = { ...ir, name: confirmedName }

  // 5. Fill in empty env vars
  ir = await promptEnvValues(ir)

  // 6. Pick targets
  const selections = await promptTargets(ALL_TARGETS)
  if (selections.length === 0) {
    warn('No targets selected. Nothing to do.')
    process.exit(0)
  }

  // 7. Dry run preview
  const wantDryRun = await promptDryRun()

  if (wantDryRun) {
    section('Preview')
    for (const { target, scope } of selections) {
      const filePath = target.configPath(scope)
      try {
        target.write(scope, ir, true)
        info(`${c.bold(target.name)} (${scope}) → ${c.dim(filePath)}`)
      } catch (e) {
        warn(`${target.name}: ${(e as Error).message}`)
      }
    }

    const ok = await promptConfirm()
    if (!ok) {
      warn('Aborted.')
      process.exit(0)
    }
  }

  // 8. Write
  section('Writing')
  const restartHints = new Set<string>()
  let wrote = 0

  for (const { target, scope } of selections) {
    const filePath = target.configPath(scope)
    try {
      target.write(scope, ir, false)
      success(`${c.bold(target.name)} (${scope})  ${c.dim(filePath)}`)
      wrote++
      if (target.restartHint) restartHints.add(target.restartHint)
    } catch (e) {
      error(`${target.name}: ${(e as Error).message}`)
    }
  }

  // 9. Done
  console.log()
  if (wrote > 0) {
    success(`Wired "${c.bold(ir.name)}" into ${wrote} target${wrote > 1 ? 's' : ''}.`)
  }

  if (restartHints.size > 0) {
    console.log()
    for (const h of restartHints) hint(h)
  }

  console.log()
}

main().catch((e: unknown) => {
  error((e as Error).message ?? String(e))
  process.exit(1)
})
