import os from 'node:os'
import path from 'node:path'
import { onPath, fileExists } from '../core/detect.ts'
import { mergeJson, removeJson } from '../core/merger.ts'
import {
  readJsonServers,
  readClaudeCodeGlobalServers,
  readClaudeCodePlugins,
} from '../core/reader.ts'
import type { IR } from '../core/ir.ts'
import type { Target, Scope } from './_base.ts'
import { irToClaudeShape } from './_base.ts'

// Canonical write targets (reads are wider but writes stay here)
const userWritePath = path.join(os.homedir(), '.claude.json')
const projectPath = path.join(process.cwd(), '.mcp.json')

export const claudeCode: Target = {
  id: 'claude-code',
  company: 'Anthropic',
  name: 'Claude Code',
  scopes: ['user', 'project'],

  detect() {
    return onPath('claude') || fileExists(userWritePath)
  },

  configPath(scope: Scope) {
    return scope === 'user' ? userWritePath : projectPath
  },

  toNative(ir: IR) {
    return irToClaudeShape(ir)
  },

  write(scope: Scope, ir: IR, dryRun: boolean) {
    const filePath = this.configPath(scope)
    return mergeJson(filePath, 'mcpServers', ir.name, this.toNative(ir), dryRun)
  },

  readServers(scope: Scope) {
    if (scope === 'user') {
      // Merge all global MCP sources: ~/.claude.json + ~/.claude/settings.json + ~/.claude/mcp.json
      const manual = readClaudeCodeGlobalServers()
      // Plugin-bundled MCPs (read-only)
      const plugins = readClaudeCodePlugins()
      // Plugins go after manual entries; dedup already happens inside each reader
      // If same name exists in both, manual wins (plugins appended, UI dedupes by name)
      const seen = new Set(manual.map(s => s.name))
      const newPlugins = plugins.filter(s => !seen.has(s.name))
      return [...manual, ...newPlugins]
    }
    // Project scope: just the local .mcp.json
    return readJsonServers(projectPath, 'mcpServers')
  },

  remove(scope: Scope, name: string, dryRun: boolean) {
    return removeJson(this.configPath(scope), 'mcpServers', name, dryRun)
  },

  restartHint: 'Claude Code picks up config changes automatically on next session start.',
}
