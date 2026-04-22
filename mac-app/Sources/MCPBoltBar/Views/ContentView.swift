import SwiftUI

// MARK: - Root content view (header + tab switcher)

struct ContentView: View {
    @EnvironmentObject var store: ServerStore
    @State private var tab: Int = 0

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14, weight: .bold))

                Text("mcpbolt")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Text("\(store.serverCount) servers · \(store.detectedTools.count) tools")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button(action: { store.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // ── Tab switcher ──────────────────────────────────────────
            Picker("", selection: $tab) {
                Text("By Tool").tag(0)
                Text("Coverage").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // ── Tab content ───────────────────────────────────────────
            Group {
                if store.detectedTools.isEmpty && !store.isLoading {
                    emptyState
                } else if tab == 0 {
                    ByToolView()
                } else {
                    CoverageView()
                }
            }
        }
        .frame(width: 460)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No MCP servers found")
                .font(.headline)
            Text("Run mcpbolt in your terminal to install one.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
