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

    enum Tab { case universal, byProject }

    @State private var tab: Tab = .universal

    // Universal tab
    @State private var selectedApps: Set<String> = []

    // By Project tab
    @State private var selectedProject: Project? = nil
    @State private var selectedProjectTools: Set<String> = []

    @State private var running = false
    @State private var resultText: String? = nil

    private var candidateTools: [ToolSummary] {
        store.detectedTools.filter { $0.toolID != sourceToolID
            && ConfigWriter.supportsNativeWrite(toolID: $0.toolID) }
    }

    private var projectScopedToolMeta: [(id: String, label: String, short: String)] {
        ALL_TOOL_META
            .filter { ToolSpecs.projectScopedTools.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if resultText == nil {
                tabBar
                Divider()
                switch tab {
                case .universal:  universalView
                case .byProject:  byProjectView
                }
                footer
            } else {
                resultView
            }
        }
    }

    // MARK: - Header

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

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Universal", icon: "globe", t: .universal)
            tabButton("By Project", icon: "folder", t: .byProject)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func tabButton(_ label: String, icon: String, t: Tab) -> some View {
        let active = tab == t
        return Button(action: { tab = t }) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(active ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(active ? ContentView.headerGrad : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Universal tab

    private var universalView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if candidateTools.isEmpty {
                    Text("No other detected apps to copy to.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text("Copies into the global config of each selected app.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        ForEach(candidateTools) { tool in
                            let c = ToolPalette.color(for: tool.toolID)
                            let already = tool.servers.contains(where: { $0.name == serverName })
                            Button(action: { toggleApp(tool.toolID) }) {
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
                                    Image(systemName: selectedApps.contains(tool.toolID)
                                          ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedApps.contains(tool.toolID) ? c : .secondary.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(selectedApps.contains(tool.toolID) ? c.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(maxHeight: 320)
    }

    // MARK: - By Project tab

    private var byProjectView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project picker — always visible
            projectPicker
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            if selectedProject != nil {
                Divider()
                projectToolList
            } else {
                Spacer()
                Text("Select a project above to choose which configs to copy into.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(20)
                Spacer()
            }
        }
        .frame(maxHeight: 320)
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Project")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if let project = selectedProject {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text(project.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(action: {
                        selectedProject = nil
                        selectedProjectTools = []
                    }) {
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
                            Button(project.displayName) { selectProject(project) }
                        }
                        Divider()
                    }
                    Button("Browse for folder…") {
                        if let path = projectStore.pickFolder() {
                            selectProject(projectStore.add(path: path))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder").font(.system(size: 11))
                        Text("Select project…").font(.system(size: 12))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
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

    private var projectToolList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pick which app configs inside the project to copy into.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    ForEach(projectScopedToolMeta, id: \.id) { meta in
                        let c = ToolPalette.color(for: meta.id)
                        let already = projectToolAlreadyHasServer(toolID: meta.id)
                        Button(action: { toggleProjectTool(meta.id) }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(c.opacity(0.14))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: ToolPalette.icon(for: meta.id))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(c)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(meta.label)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(projectConfigPath(toolID: meta.id))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                if already {
                                    Text("— will overwrite")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                Image(systemName: selectedProjectTools.contains(meta.id)
                                      ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedProjectTools.contains(meta.id) ? c : .secondary.opacity(0.5))
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selectedProjectTools.contains(meta.id) ? c.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Footer

    private var selectionSummary: String {
        switch tab {
        case .universal:
            let n = selectedApps.count
            return n == 0 ? "0 selected" : "\(n) app\(n == 1 ? "" : "s")"
        case .byProject:
            let n = selectedProjectTools.count
            return n == 0 ? "0 selected" : "\(n) config\(n == 1 ? "" : "s")"
        }
    }

    private var hasSelection: Bool {
        switch tab {
        case .universal:  return !selectedApps.isEmpty
        case .byProject:  return !selectedProjectTools.isEmpty && selectedProject != nil
        }
    }

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

    // MARK: - Result

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

    // MARK: - Helpers

    private func toggleApp(_ id: String) {
        if selectedApps.contains(id) { selectedApps.remove(id) } else { selectedApps.insert(id) }
    }

    private func toggleProjectTool(_ id: String) {
        if selectedProjectTools.contains(id) { selectedProjectTools.remove(id) } else { selectedProjectTools.insert(id) }
    }

    private func selectProject(_ project: Project) {
        selectedProject = project
        // Pre-check tools that already have configs in this project
        selectedProjectTools = Set(projectStore.detectedToolIDs(for: project))
        // Always pre-check claude-code as a sensible default if nothing is detected
        if selectedProjectTools.isEmpty { selectedProjectTools = ["claude-code"] }
    }

    private func projectToolAlreadyHasServer(toolID: String) -> Bool {
        guard let project = selectedProject else { return false }
        return ConfigWriter.readServer(
            toolID: toolID, scope: .project,
            projectRoot: project.path, name: serverName) != nil
    }

    private func projectConfigPath(toolID: String) -> String {
        switch toolID {
        case "claude-code": return ".mcp.json"
        case "cursor":      return ".cursor/mcp.json"
        case "vscode":      return ".vscode/mcp.json"
        case "roo":         return ".roo/mcp.json"
        case "codex":       return ".codex/config.toml"
        default:            return ""
        }
    }

    // MARK: - Run

    private func run() {
        running = true
        var totalOk = 0
        var totalFail = 0

        switch tab {
        case .universal:
            let outcome = store.copyServer(name: serverName, from: sourceToolID, to: Array(selectedApps))
            totalOk   += outcome.successes.count
            totalFail += outcome.failures.count

        case .byProject:
            if let project = selectedProject,
               let config = ConfigWriter.readServer(toolID: sourceToolID, name: serverName) {
                for toolID in selectedProjectTools {
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
        }

        running = false
        if totalFail == 0 {
            resultText = "Copied to \(totalOk) destination\(totalOk == 1 ? "" : "s")."
        } else if totalOk == 0 {
            resultText = "Copy failed — check tool configs and try again."
        } else {
            resultText = "Copied to \(totalOk) destination\(totalOk == 1 ? "" : "s"); \(totalFail) failed."
        }
    }
}
