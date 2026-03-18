import AppKit
import Combine
import SwiftUI

// MARK: - ANIMA module model

struct AnimaModule: Identifiable {
    let id: String  // module name (e.g. "azoth")
    let displayName: String
    let description: String
    var status: ModuleStatus

    enum ModuleStatus {
        case running, stopped, unhealthy, unknown

        var label: String {
            switch self {
            case .running:   return "RUNNING"
            case .stopped:   return "STOPPED"
            case .unhealthy: return "UNHEALTHY"
            case .unknown:   return "---"
            }
        }

        var dotColor: Color {
            switch self {
            case .running:   return RF.green
            case .stopped:   return Color.white.opacity(0.2)
            case .unhealthy: return RF.accent
            case .unknown:   return Color.white.opacity(0.1)
            }
        }
    }

    static let knownModules: [String: String] = [
        "azoth": "Detection",
        "chronos": "Tracking",
        "monad": "Reasoning",
        "loci": "Mapping",
        "osiris": "Diagnostics",
        "petra": "Planning",
    ]
}

// MARK: - ANIMA state (singleton, polls Docker)

@MainActor
final class AnimaState: ObservableObject {
    static let shared = AnimaState()

    @Published var modules: [AnimaModule] = []
    @Published var isLoading = false

    private var timer: Timer?
    private var configSub: AnyCancellable?

    private init() {
        buildModuleList()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard SidebarVisibility.shared.isVisible else { return }
                self?.refresh()
            }
        }

        // Rebuild module list when ANIMA config changes in Preferences
        configSub = TerminalSettings.shared.$animaConfig
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.buildModuleList()
                    self?.refresh()
                }
            }
    }

    deinit {
        timer?.invalidate()
    }

    var runningCount: Int { modules.filter { $0.status == .running }.count }

    private func buildModuleList() {
        let config = TerminalSettings.shared.animaConfig
        modules = config.moduleNames.map { name in
            AnimaModule(
                id: name,
                displayName: name.uppercased(),
                description: AnimaModule.knownModules[name] ?? "",
                status: .unknown
            )
        }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Self.queryDockerContainers()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.updateStatuses(from: result)
            }
        }
    }

    private func updateStatuses(from containers: [String: String]) {
        for i in modules.indices {
            let name = modules[i].id
            // Match containers with prefix "anima-" or exact module name
            let key = containers.keys.first { k in
                k.lowercased().contains("anima") && k.lowercased().contains(name)
                || k.lowercased() == name
            }
            if let key, let status = containers[key] {
                if status.contains("Up") {
                    modules[i].status = status.contains("unhealthy") ? .unhealthy : .running
                } else {
                    modules[i].status = .stopped
                }
            } else {
                modules[i].status = .unknown
            }
        }
    }

    nonisolated private static func queryDockerContainers() -> [String: String] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-c", "export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH && docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        do {
            try proc.run()
            // Kill after 5 seconds to prevent hangs
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if proc.isRunning { proc.terminate() }
            }
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            var result: [String: String] = [:]
            for line in output.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1)
                if parts.count == 2 {
                    result[String(parts[0])] = String(parts[1])
                }
            }
            return result
        } catch {
            return [:]
        }
    }
}

// MARK: - ANIMA sidebar panel

struct AnimaPanelView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var state = AnimaState.shared
    @State private var isExpanded: Bool = UserDefaults.standard.object(forKey: "panelExpanded.anima") as? Bool ?? true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { isExpanded.toggle() }
                UserDefaults.standard.set(isExpanded, forKey: "panelExpanded.anima")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 10)

                    Text("ANIMA MODULES")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(RF.accent)
                        .tracking(1)

                    Spacer()

                    if state.runningCount > 0 {
                        Text("\(state.runningCount)/\(state.modules.count)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(RF.green)
                    }

                    if state.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle().fill(RF.accent.opacity(0.1)).frame(height: 1)
                    .padding(.horizontal, 8)

                VStack(spacing: 1) {
                    ForEach(state.modules) { module in
                        AnimaModuleRow(module: module) { action in
                            handleModuleAction(module: module, action: action)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
    }

    /// Shell-escape a string for safe interpolation into commands.
    private func shellEscape(_ s: String) -> String {
        // Only allow safe characters unquoted
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~/"))
        if s.unicodeScalars.allSatisfy({ allowed.contains($0) }) { return s }
        // Single-quote the string, escaping embedded single quotes
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func handleModuleAction(module: AnimaModule, action: ModuleAction) {
        let mgr = AppDelegate.shared?.focusedTabManager ?? tabManager

        let config = TerminalSettings.shared.animaConfig
        let composePath = config.composePath
        let expandedPath = shellEscape(NSString(string: composePath).expandingTildeInPath)
        // Use resolved container name from module config if available
        let moduleConfig = config.moduleConfigs.first(where: { $0.name == module.id })
        let containerName = shellEscape(moduleConfig?.resolvedContainerName ?? module.id)
        let moduleId = shellEscape(module.id)
        let profile = moduleConfig?.profile ?? "cpu"

        let profileFlag = profile == "gpu" ? " --profile gpu" : ""
        let command: String
        switch action {
        case .logs:    command = "cd \(expandedPath) && docker compose logs -f \(moduleId)"
        case .start:   command = "cd \(expandedPath) && docker compose\(profileFlag) up -d \(moduleId)"
        case .stop:    command = "cd \(expandedPath) && docker compose stop \(moduleId)"
        case .restart: command = "cd \(expandedPath) && docker compose restart \(moduleId)"
        case .shell:   command = "docker exec -it \(containerName) /bin/bash"
        case .ssh:
            guard let mc = moduleConfig, !mc.sshHost.isEmpty else { return }
            let sshConn = SSHConnectionConfig(
                label: mc.name.uppercased(),
                host: mc.sshHost,
                user: mc.sshUser,
                port: mc.sshPort,
                keyPath: mc.sshKeyPath
            )
            mgr.createSSHTab(config: sshConn)
            return
        }

        let tab = mgr.createTab()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tab.terminalView?.sendText(command + "\n")
        }
    }
}

enum ModuleAction {
    case logs, start, stop, restart, shell, ssh
}

struct AnimaModuleRow: View {
    let module: AnimaModule
    let onAction: (ModuleAction) -> Void
    @State private var isHovering = false

    private var sshHost: String {
        TerminalSettings.shared.animaConfig.moduleConfigs
            .first(where: { $0.name == module.id })?.sshHost ?? ""
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(module.status.dotColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(module.displayName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(module.status == .running ? 0.8 : 0.35))

                if !module.description.isEmpty {
                    Text(module.description)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                }
            }

            Spacer()

            if isHovering {
                Text(module.status.label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(module.status.dotColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onAction(.logs) }
        .contextMenu {
            Button("View Logs") { onAction(.logs) }
            Divider()
            Button("Start") { onAction(.start) }
                .disabled(module.status == .running)
            Button("Stop") { onAction(.stop) }
                .disabled(module.status != .running)
            Button("Restart") { onAction(.restart) }
            Divider()
            Button("Shell (Docker)") { onAction(.shell) }
                .disabled(module.status != .running)
            Button("SSH (Remote)") { onAction(.ssh) }
                .disabled(sshHost.isEmpty)
        }
    }
}
