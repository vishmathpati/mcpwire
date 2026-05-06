import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { parse as parseToml } from 'smol-toml'
import { parse as parseYaml } from 'yaml'

export type ServerSource = 'manual' | 'extension' | 'plugin'

export interface ServerEntry {
  name: string
  transport: 'stdio' | 'http' | 'sse'
  command?: string
  args?: string[]
  env?: Record<string, string>
  url?: string
  headers?: Record<string, string>
  needsAuth: boolean
  oauthNote?: string
  source: ServerSource
  // true = installed by the app itself (DXT/plugin); mcpbolt cannot remove it
  readonly?: boolean
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function home(...parts: string[]): string {
  return path.join(os.homedir(), ...parts)
}

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

const CRED_RE = /KEY|TOKEN|SECRET|PASSWORD|AUTH|CREDENTIAL/i

function detectAuth(raw: Record<string, unknown>): { needsAuth: boolean; oauthNote?: string } {
  const env = raw['env'] as Record<string, string> | undefined
  const headers = raw['headers'] as Record<string, string> | undefined
  const note = raw['note'] as string | undefined

  if (env && Object.keys(env).some(k => CRED_RE.test(k))) return { needsAuth: true }
  if (headers && Object.values(headers).some(v => v.startsWith('Bearer') || v.includes('${') )) return { needsAuth: true }
  if (note?.toLowerCase().includes('oauth')) return { needsAuth: true, oauthNote: note }
  return { needsAuth: false }
}

function rawToEntry(
  name: string,
  raw: Record<string, unknown>,
  source: ServerSource = 'manual',
  readonly = false,
): ServerEntry {
  const hasUrl = typeof raw['url'] === 'string'
  const transport = hasUrl
    ? ((raw['type'] === 'sse' ? 'sse' : 'http') as 'http' | 'sse')
    : 'stdio'

  const { needsAuth, oauthNote } = detectAuth(raw)

  const entry: ServerEntry = { name, transport, needsAuth, source }
  if (oauthNote) entry.oauthNote = oauthNote
  if (readonly) entry.readonly = true

  if (transport === 'stdio') {
    entry.command = raw['command'] as string | undefined
    entry.args = raw['args'] as string[] | undefined
    const env = raw['env'] as Record<string, string> | undefined
    if (env && Object.keys(env).length) entry.env = env
  } else {
    entry.url = raw['url'] as string
    const headers = raw['headers'] as Record<string, string> | undefined
    if (headers && Object.keys(headers).length) entry.headers = headers
  }

  return entry
}

// Deduplicate by name — first occurrence wins
function dedupeByName(entries: ServerEntry[]): ServerEntry[] {
  const seen = new Set<string>()
  return entries.filter(e => {
    if (seen.has(e.name)) return false
    seen.add(e.name)
    return true
  })
}

// ── Plugin .mcp.json parser ───────────────────────────────────────────────────

// Handles both formats:
//   Wrapped:  { "mcpServers": { "name": {...} } }
//   Flat:     { "name": { "command"|"url": ... } }
function parseMcpJsonData(
  data: Record<string, unknown>,
  source: ServerSource,
  readonly: boolean,
): ServerEntry[] {
  // Try wrapped format first
  const wrapped = data['mcpServers'] as Record<string, unknown> | undefined
  if (wrapped && typeof wrapped === 'object') {
    return Object.entries(wrapped).map(([name, val]) =>
      rawToEntry(name, val as Record<string, unknown>, source, readonly)
    )
  }

  // Flat format: every top-level key whose value has command or url is a server
  return Object.entries(data)
    .filter(([, val]) => {
      if (!val || typeof val !== 'object') return false
      const v = val as Record<string, unknown>
      return typeof v['command'] === 'string' || typeof v['url'] === 'string'
    })
    .map(([name, val]) =>
      rawToEntry(name, val as Record<string, unknown>, source, readonly)
    )
}

function readMcpJsonFile(
  filePath: string,
  source: ServerSource,
  readonly: boolean,
): ServerEntry[] {
  if (!fs.existsSync(filePath)) return []
  try {
    const raw = fs.readFileSync(filePath, 'utf-8')
    const data = JSON.parse(stripComments(raw)) as Record<string, unknown>
    return parseMcpJsonData(data, source, readonly)
  } catch {
    return []
  }
}

// ── Standard readers ──────────────────────────────────────────────────────────

// Read from a JSON file with mcpServers / context_servers / servers key
export function readJsonServers(filePath: string, key: string): ServerEntry[] {
  if (!fs.existsSync(filePath)) return []
  try {
    const raw = fs.readFileSync(filePath, 'utf-8')
    const data = JSON.parse(stripComments(raw)) as Record<string, unknown>

    const map = data[key] as Record<string, unknown> | undefined
    if (!map || typeof map !== 'object') return []

    return Object.entries(map).map(([name, val]) => {
      const v = val as Record<string, unknown>
      // Zed wraps command: { path, args }
      if (v['command'] && typeof v['command'] === 'object') {
        const cmd = v['command'] as Record<string, unknown>
        return rawToEntry(name, { command: cmd['path'], args: cmd['args'] }, 'manual')
      }
      return rawToEntry(name, v, 'manual')
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
      rawToEntry((entry['name'] as string) ?? 'unknown', entry, 'manual')
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
      rawToEntry(name, val as Record<string, unknown>, 'manual')
    )
  } catch {
    return []
  }
}

// ── Claude Code multi-file global reader ──────────────────────────────────────

// Claude Code global MCP servers live in up to 3 files; merge them all.
// Priority: ~/.claude.json > ~/.claude/settings.json > ~/.claude/mcp.json
export function readClaudeCodeGlobalServers(): ServerEntry[] {
  const all: ServerEntry[] = [
    ...readJsonServers(home('.claude.json'), 'mcpServers'),
    ...readJsonServers(home('.claude', 'settings.json'), 'mcpServers'),
    ...readJsonServers(home('.claude', 'mcp.json'), 'mcpServers'),
  ]
  return dedupeByName(all)
}

// ── Claude Code plugin reader ─────────────────────────────────────────────────

interface InstalledPlugin {
  scope: string
  projectPath?: string
  installPath: string
  version: string
}

interface InstalledPluginsFile {
  version: number
  plugins: Record<string, InstalledPlugin[]>
}

export function readClaudeCodePlugins(): ServerEntry[] {
  const registryPath = home('.claude', 'plugins', 'installed_plugins.json')
  const settingsPath = home('.claude', 'settings.json')
  if (!fs.existsSync(registryPath)) return []

  // Get enabled/disabled state from settings.json
  let enabledPlugins: Record<string, boolean> = {}
  try {
    const s = JSON.parse(stripComments(fs.readFileSync(settingsPath, 'utf-8'))) as Record<string, unknown>
    enabledPlugins = (s['enabledPlugins'] as Record<string, boolean>) ?? {}
  } catch { /* settings.json missing or malformed — treat all as enabled */ }

  let registry: InstalledPluginsFile
  try {
    registry = JSON.parse(fs.readFileSync(registryPath, 'utf-8')) as InstalledPluginsFile
  } catch {
    return []
  }

  const servers: ServerEntry[] = []

  for (const [pluginKey, installs] of Object.entries(registry.plugins ?? {})) {
    // Skip if explicitly disabled
    if (enabledPlugins[pluginKey] === false) continue

    // Use the user-scoped install; fall back to the first entry
    const install = installs.find(i => i.scope === 'user') ?? installs[0]
    if (!install?.installPath) continue

    const mcpFile = path.join(install.installPath, '.mcp.json')
    const entries = readMcpJsonFile(mcpFile, 'plugin', true)
    servers.push(...entries)
  }

  return dedupeByName(servers)
}

// ── Codex plugin reader ───────────────────────────────────────────────────────

export function readCodexPlugins(configFilePath: string): ServerEntry[] {
  if (!fs.existsSync(configFilePath)) return []

  let data: Record<string, unknown>
  try {
    data = parseToml(fs.readFileSync(configFilePath, 'utf-8')) as Record<string, unknown>
  } catch {
    return []
  }

  // Build marketplace → local cache path map
  const marketplaces = (data['marketplaces'] as Record<string, Record<string, unknown>>) ?? {}
  const mktCacheDirs: Record<string, string> = {}
  for (const [mktName, mkt] of Object.entries(marketplaces)) {
    const srcType = mkt['source_type'] as string | undefined
    const src = mkt['source'] as string | undefined
    if (!src) continue
    if (srcType === 'local') {
      // The plugin cache lives alongside the local source or at the standard cache path
      mktCacheDirs[mktName] = home('.codex', 'plugins', 'cache', mktName)
    } else {
      // git-backed marketplace — cache is always here
      mktCacheDirs[mktName] = home('.codex', 'plugins', 'cache', mktName)
    }
  }

  const plugins = (data['plugins'] as Record<string, Record<string, unknown>>) ?? {}
  const servers: ServerEntry[] = []

  for (const [pluginKey, pluginCfg] of Object.entries(plugins)) {
    if (pluginCfg['enabled'] === false) continue

    // pluginKey format: "name@marketplace"
    const atIdx = pluginKey.lastIndexOf('@')
    if (atIdx < 0) continue
    const pluginName = pluginKey.slice(0, atIdx)
    const marketplace = pluginKey.slice(atIdx + 1)

    const cacheDir = mktCacheDirs[marketplace]
    if (!cacheDir || !fs.existsSync(cacheDir)) continue

    // Find the versioned subdirectory for this plugin
    const pluginBaseDir = path.join(cacheDir, pluginName)
    if (!fs.existsSync(pluginBaseDir)) continue

    let mcpFile: string | undefined
    try {
      const versions = fs.readdirSync(pluginBaseDir)
      // Pick the last version dir (typically there is only one)
      const versionDir = versions[versions.length - 1]
      if (versionDir) {
        const candidate = path.join(pluginBaseDir, versionDir, '.mcp.json')
        if (fs.existsSync(candidate)) mcpFile = candidate
      }
    } catch { continue }

    if (!mcpFile) continue
    servers.push(...readMcpJsonFile(mcpFile, 'plugin', true))
  }

  return dedupeByName(servers)
}

// ── Claude Desktop DXT extension reader ───────────────────────────────────────

const DXT_BASE = home('Library', 'Application Support', 'Claude')
const DXT_REGISTRY = path.join(DXT_BASE, 'extensions-installations.json')
const DXT_EXT_DIR = path.join(DXT_BASE, 'Claude Extensions')
const DXT_SETTINGS_DIR = path.join(DXT_BASE, 'Claude Extensions Settings')

interface DxtManifest {
  name?: string
  display_name?: string
  server?: {
    mcp_config?: {
      command?: string
      args?: string[]
      env?: Record<string, string>
    }
  }
  user_config?: Record<string, unknown>
}

interface DxtInstall {
  id: string
  manifest: DxtManifest
}

interface DxtRegistry {
  extensions: Record<string, DxtInstall>
}

function resolveDxtArgs(
  args: string[],
  extDir: string,
  userConfig: Record<string, unknown>,
): string[] {
  return args.map(arg => {
    let s = arg
    s = s.replace(/\$\{__dirname\}/g, extDir)
    s = s.replace(/\$\{HOME\}/g, os.homedir())
    s = s.replace(/\$\{DOCUMENTS\}/g, path.join(os.homedir(), 'Documents'))
    // ${user_config.field} — handle array values by joining with space
    s = s.replace(/\$\{user_config\.([^}]+)\}/g, (_m, field: string) => {
      const val = userConfig[field]
      if (Array.isArray(val)) return val.join(' ')
      return val != null ? String(val) : ''
    })
    return s
  })
}

export function readDxtExtensions(): ServerEntry[] {
  if (!fs.existsSync(DXT_REGISTRY)) return []

  let registry: DxtRegistry
  try {
    registry = JSON.parse(fs.readFileSync(DXT_REGISTRY, 'utf-8')) as DxtRegistry
  } catch {
    return []
  }

  const servers: ServerEntry[] = []

  for (const [extId, install] of Object.entries(registry.extensions ?? {})) {
    // Read per-extension settings (enabled state + user config)
    const settingsFile = path.join(DXT_SETTINGS_DIR, `${extId}.json`)
    let isEnabled = true
    let userConfig: Record<string, unknown> = {}
    if (fs.existsSync(settingsFile)) {
      try {
        const s = JSON.parse(fs.readFileSync(settingsFile, 'utf-8')) as {
          isEnabled?: boolean
          userConfig?: Record<string, unknown>
        }
        isEnabled = s.isEnabled !== false
        userConfig = s.userConfig ?? {}
      } catch { /* treat as enabled */ }
    }
    if (!isEnabled) continue

    const mcp = install.manifest?.server?.mcp_config
    if (!mcp) continue

    const extDir = path.join(DXT_EXT_DIR, extId)
    const displayName = install.manifest.display_name ?? install.manifest.name ?? extId

    const rawArgs = mcp.args ?? []
    const resolvedArgs = resolveDxtArgs(rawArgs, extDir, userConfig)

    const raw: Record<string, unknown> = {
      command: mcp.command,
      args: resolvedArgs,
      ...(mcp.env ? { env: mcp.env } : {}),
    }

    servers.push(rawToEntry(displayName, raw, 'extension', true))
  }

  return servers
}
