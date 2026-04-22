import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "MCPBolt — One‑click MCP servers for every app",
  description:
    "A tiny menu bar app that installs, syncs, and manages MCP servers across Claude Desktop, Cursor, VS Code, Windsurf, Zed, and more. Local, free, open source.",
  openGraph: {
    title: "MCPBolt — One‑click MCP servers for every app",
    description:
      "A tiny menu bar app that installs, syncs, and manages MCP servers across Claude Desktop, Cursor, VS Code, Windsurf, Zed, and more.",
    type: "website",
  },
  icons: {
    icon: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
