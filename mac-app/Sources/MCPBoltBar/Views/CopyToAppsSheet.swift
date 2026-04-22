import SwiftUI
import AppKit

// MARK: - Copy a server from one app to one or more other apps.

struct CopyToAppsSheet: View {
    @EnvironmentObject var store: ServerStore
    let serverName: String
    let sourceToolID: String
    let sourceToolLabel: String
    let onClose: () -> Void

    @State private var selected: Set<String> = []
    @State private var running = false
    @State private var resultText: String? = nil

    private var candidateTools: [ToolSummary] {
        store.detectedTools.filter { $0.toolID != sourceToolID
            && ConfigWriter.supportsNativeWrite(toolID: $0.toolID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if resultText == nil {
                pickerView
                footer
            } else {
                resultView
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("Copy \(serverName)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text("from \(sourceToolLabel)")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.60))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(ContentView.headerGrad)
    }

    private var pickerView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if candidateTools.isEmpty {
                    Text("No other detected apps to copy to.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text("Pick the apps to copy this server into.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        ForEach(candidateTools) { tool in
                            let c = ToolPalette.color(for: tool.toolID)
                            let already = tool.servers.contains(where: { $0.name == serverName })
                            Button(action: { toggle(tool.toolID) }) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(c.opacity(0.14))
                                            .frame(width: 26, height: 26)
                                        Image(systemName: ToolPalette.icon(for: tool.toolID))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(c)
                                    }
                                    Text(tool.label)
                                        .font(.system(size: 12, weight: .medium))
                                    if already {
                                        Text("— already installed, will overwrite")
                                            .font(.system(size: 10))
                                            .foregroundColor(.orange)
                                    }
                                    Spacer()
                                    Image(systemName: selected.contains(tool.toolID)
                                          ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selected.contains(tool.toolID) ? c : .secondary.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(selected.contains(tool.toolID) ? c.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(maxHeight: 400)
    }

    private var footer: some View {
        HStack {
            Button(action: onClose) {
                Text("Cancel").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("\(selected.count) selected")
                .font(.system(size: 11)).foregroundColor(.secondary)
            Button(action: run) {
                HStack(spacing: 5) {
                    if running { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
                    Image(systemName: "square.and.arrow.up.fill").font(.system(size: 11))
                    Text("Copy").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(ContentView.headerGrad)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .opacity(selected.isEmpty ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty || running)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green).font(.system(size: 20))
                Text(resultText ?? "").font(.system(size: 12))
                Spacer()
            }
            HStack {
                Spacer()
                Button(action: onClose) {
                    Text("Done").font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(ContentView.headerGrad)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func run() {
        running = true
        let outcome = store.copyServer(
            name: serverName,
            from: sourceToolID,
            to: Array(selected)
        )
        running = false
        let ok = outcome.successes.count
        let fail = outcome.failures.count
        if fail == 0 {
            resultText = "Copied to \(ok) app\(ok == 1 ? "" : "s")."
        } else if ok == 0 {
            resultText = "Couldn't copy: \(outcome.failures.first?.message ?? "unknown error")"
        } else {
            resultText = "Copied to \(ok) app\(ok == 1 ? "" : "s"); \(fail) failed."
        }
    }
}
