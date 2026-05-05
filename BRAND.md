# BRAND.md — Project Hub
> What every agent must know before touching this project.

## Product

- **Name:** Project Hub
- **One sentence:** A native macOS menu bar app for managing AI coding tool configurations (skills, agents, MCP servers, hooks, CLAUDE.md) across every project in one place.
- **Also in this repo:** mcpbolt CLI (`src/`) — open source MCP installer — deprioritized, focus is Project Hub

## User

- **Who it's for:** Developers using Claude Code, Cursor, Codex, or similar AI coding tools across multiple projects
- **Problem it solves:** Managing skills, agents, MCP configs, and CLAUDE.md files manually across dozens of projects is error-prone and tedious
- **What it is NOT:** A cloud service, a team collaboration tool, a chat app, a generic launcher

## Personality

- **Tone:** Fast and opinionated — native macOS, premium, minimal. Does one job perfectly.
- **Values:** Speed, privacy, local-only, native macOS feel, zero config required
- **Feel:** Like a pro tool that respects your machine. Nothing talks to the cloud. Nothing asks you to sign in.

## What NOT to build

- No cloud sync / remote storage / accounts of any kind
- No team features, SSO, enterprise pricing, multi-seat licenses
- No chat interface, AI assistant, or LLM calls inside the app
- No feature creep into generic launcher territory (not Raycast, not Alfred)
- No Windows version, no web app version
- No subscription pricing — lifetime only if paid
