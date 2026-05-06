import os from 'node:os'
import path from 'node:path'
import { appExists, dirExists } from '../core/detect.ts'
import { mergeJson, removeJson } from '../core/merger.ts'
import { readJsonServers, readDxtExtensions } from '../core/reader.ts'
import type { IR } from '../core/ir.ts'
import type { Target, Scope } from './_base.ts'
import { irToClaudeShape } from './_base.ts'

const configPath = path.join(
  os.homedir(),
  'Library',
  'Application Support',
  'Claude',
  'claude_desktop_config.json',
)

export const claudeDesktop: Target = {
  id: 'claude-desktop',
  company: 'Anthropic',
  name: 'Claude Desktop',
  scopes: ['user'],

  detect() {
    return (
      dirExists('Library', 'Application Support', 'Claude') || appExists('Claude')
    )
  },

  configPath(_scope: Scope) {
    return configPath
  },

  toNative(ir: IR) {
    return irToClaudeShape(ir)
  },

  write(scope: Scope, ir: IR, dryRun: boolean) {
    return mergeJson(configPath, 'mcpServers', ir.name, this.toNative(ir), dryRun)
  },

  readServers(_scope: Scope) {
    // Manual servers from claude_desktop_config.json
    const manual = readJsonServers(configPath, 'mcpServers')
    // DXT extensions installed via Claude Desktop's official registry
    const extensions = readDxtExtensions()
    // Manual wins on name collision
    const seen = new Set(manual.map(s => s.name))
    const newExt = extensions.filter(s => !seen.has(s.name))
    return [...manual, ...newExt]
  },

  remove(_scope: Scope, name: string, dryRun: boolean) {
    return removeJson(configPath, 'mcpServers', name, dryRun)
  },

  restartHint: 'Quit and reopen Claude Desktop to load the new server.',
}
