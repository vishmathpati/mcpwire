import { select, checkbox } from '@inquirer/prompts'
import { ALL_TARGETS } from '../targets/index.ts'
import type { Target, Scope } from '../targets/_base.ts'
import { success, warn, error, section, c } from './display.ts'

type Location = { target: Target; scope: Scope }

export async function runRemove(nameArg?: string): Promise<void> {
  console.log()

  // Build map: serverName → where it's installed
  const serverMap = new Map<string, Location[]>()

  for (const target of ALL_TARGETS) {
    if (!target.detect()) continue
    for (const scope of target.scopes) {
      for (const server of target.readServers(scope)) {
        const list = serverMap.get(server.name) ?? []
        list.push({ target, scope })
        serverMap.set(server.name, list)
      }
    }
  }

  if (serverMap.size === 0) {
    warn('No MCP servers found across any detected tool.')
    console.log()
    return
  }

  // Resolve the server name — from arg or prompt
  let serverName = nameArg?.trim()

  if (!serverName) {
    const sorted = [...serverMap.keys()].sort()
    serverName = await select({
      message: 'Which MCP server do you want to remove?',
      choices: sorted.map((name) => ({
        name: `${name}  ${c.dim('(' + (serverMap.get(name)?.length ?? 0) + ' tool' + ((serverMap.get(name)?.length ?? 0) !== 1 ? 's' : '') + ')')}`,
        value: name,
      })),
    })
  }

  const locations = serverMap.get(serverName)
  if (!locations?.length) {
    error(`Server "${serverName}" not found in any detected tool.`)
    console.log()
    return
  }

  // Let user pick which tools to remove from (all pre-checked)
  const selections = await checkbox<Location>({
    message: `Remove "${c.bold(serverName)}" from which tools?`,
    choices: locations.map(({ target, scope }) => ({
      name: `${target.name}  ${c.dim('(' + scope + ')  ' + target.configPath(scope))}`,
      value: { target, scope },
      checked: true,
    })),
  })

  if (selections.length === 0) {
    warn('Nothing selected — no changes made.')
    console.log()
    return
  }

  // Remove from each selected target
  section('Removing')

  let removed = 0
  for (const { target, scope } of selections) {
    try {
      const found = target.remove(scope, serverName, false)
      if (found) {
        success(`${c.bold(target.name)} (${scope})  ${c.dim(target.configPath(scope))}`)
        removed++
        if (target.restartHint) console.log(c.dim('    → ' + target.restartHint))
      } else {
        warn(`${target.name} (${scope}) — server not found in config (already removed?)`)
      }
    } catch (e) {
      error(`${target.name}: ${(e as Error).message}`)
    }
  }

  console.log()
  if (removed > 0) {
    success(`Removed "${c.bold(serverName)}" from ${removed} tool${removed !== 1 ? 's' : ''}.`)
  }
  console.log()
}
