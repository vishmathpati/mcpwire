import SwiftUI
import AppKit

// MARK: - Copy a server from one app to one or more other apps.

struct CopyToAppsSheet: View {
    @EnvironmentObject var store: ServerStore
    @EnvironmentObject var projectStore: ProjectStore
    let serverName: String
    let sourceToolID: String
    let sourceToolLabel: String
    let onClose: () -> Void

    @State private var selected: Set<String> = []
    @State private var selectedProject: Project? = nil
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
        VStack(alignment: .leading, spacing: 0) {
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
            .frame(maxHeight: 300)

            Divider()

            projectPickerSection
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
    }

    private var projectPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Project (optional)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if let project = selectedProject {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(project.displayName)
                            .font(.system(size: 12, weight: .medium))
                        let tools = projectStore.detectedToolIDs(for: project)
                        let toolNames = tools.isEmpty ? ["claude-code"] : tools
                        Text("→ \(toolNames.joined(separator: ", "))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { selectedProject = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.blue.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Menu {
                    if !projectStore.projects.isEmpty {
                        ForEach(projectStore.projects) { project in
                            Button(project.displayName) {
                                selectedProject = project
                            }
                        }
                        Divider()
                    }
                    Button("Browse for folder…") {
                        if let path = projectStore.pickFolder() {
                            selectedProject = projectStore.add(path: path)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Select project…")
                            .font(.system(size: 12))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    private var selectionSummary: String {
        var parts: [String] = []
        if !selected.isEmpty { parts.append("\(selected.count) app\(selected.count == 1 ? "" : "s")") }
        if selectedProject != nil { parts.append("1 project") }
        return parts.isEmpty ? "0 selected" : parts.joined(separator: " + ")
    }

    private var hasSelection: Bool { !selected.isEmpty || selectedProject != nil }

    private var footer: some View {
        HStack {
            Button(action: onClose) {
                Text("Cancel").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(selectionSummary)
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
                .opacity(hasSelection ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection || running)
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
        var totalOk = 0
        var totalFail = 0

        if !selected.isEmpty {
            let outcome = store.copyServer(name: serverName, from: sourceToolID, to: Array(selected))
            totalOk   += outcome.successes.count
            totalFail += outcome.failures.count
        }

        if let project = selectedProject,
           let config = ConfigWriter.readServer(toolID: sourceToolID, name: serverName) {
            let existing = projectStore.detectedToolIDs(for: project)
            let toolsToWrite = existing.isEmpty ? ["claude-code"] : existing
            for toolID in toolsToWrite {
                guard ToolSpecs.projectScopedTools.contains(toolID) else { continue }
                do {
                    try ConfigWriter.writeServer(
                        toolID: toolID, scope: .project,
                        projectRoot: project.path, name: serverName, config: config)
                    totalOk += 1
                } catch {
                    totalFail += 1
                }
            }
        }

        running = false
        if totalFail == 0 {
            resultText = "Copied to \(totalOk) destination\(totalOk == 1 ? "" : "s")."
        } else if totalOk == 0 {
            resultText = "Couldn't copy: check tool configs and try again."
        } else {
            resultText = "Copied to \(totalOk) destination\(totalOk == 1 ? "" : "s"); \(totalFail) failed."
        }
    }
}
