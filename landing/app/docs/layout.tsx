import type { Metadata } from "next";
import { DocsSidebar } from "./DocsSidebar";

export const metadata: Metadata = {
  title: {
    default: "Docs",
    template: "%s · MCPBolt Docs",
  },
  description:
    "Documentation for MCPBolt — the MCP server installer for Claude, Cursor, VS Code, Windsurf, Zed, Codex, and more.",
};

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="container docs-shell">
      <DocsSidebar />
      <div className="docs-main">{children}</div>
    </div>
  );
}
