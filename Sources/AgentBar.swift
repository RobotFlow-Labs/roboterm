import SwiftUI

// MARK: - Agent Launcher Bar

struct AgentBar: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var settings = TerminalSettings.shared

    private var enabledAgents: [AgentConfig] {
        settings.agents.filter(\.enabled)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Agent buttons — loaded from settings
            if enabledAgents.isEmpty {
                Text("NO AGENTS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(RF.dim)
                    .padding(.horizontal, 8)
            } else {
                ForEach(enabledAgents) { agent in
                    BarButton(
                        label: agent.name,
                        dotColor: Color(nsColor: NSColor(hex: agent.colorHex) ?? .white)
                    ) {
                        launchAgent(agent)
                    }
                }
            }

            // Separator
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 14)
                .padding(.horizontal, 2)

            // ROS2 quick-launch tools
            BarButton(label: "nodes", dotColor: RF.green) { launchCommand("ros2 node list") }
            BarButton(label: "topics", dotColor: RF.green) { launchCommand("ros2 topic list -v") }
            BarButton(label: "services", dotColor: RF.green) { launchCommand("ros2 service list") }
            BarButton(label: "params", dotColor: RF.green) { launchCommand("ros2 param list") }

            // Separator
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 14)
                .padding(.horizontal, 2)

            // Sim & tools
            BarButton(label: "gazebo", dotColor: RF.cyan) { launchCommand("gz sim") }
            BarButton(label: "rviz2", dotColor: RF.purple) { launchCommand("rviz2") }
            BarButton(label: "rqt", dotColor: RF.yellow) { launchCommand("rqt") }
            BarButton(label: "doctor", dotColor: RF.yellow) { launchCommand("ros2 doctor --report") }

            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
        .background(RF.barBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RF.accent.opacity(0.15)).frame(height: 1)
        }
    }

    private func launchAgent(_ agent: AgentConfig) {
        launchCommand(agent.fullCommand)
    }

    private func launchCommand(_ command: String) {
        // TUI/long-running commands open in a new tab, quick commands run in current tab
        let agentCommands = settings.agents.map(\.command)
        let tuiCommands = agentCommands + ["rviz2", "rqt", "rqt_graph", "gz sim",
                           "python3 -m mujoco.viewer", "isaac-sim"]
        let openInNewTab = tuiCommands.contains(where: { command.hasPrefix($0) })

        // If current tab is SSH, always open a new local tab (don't send agents/tools into SSH)
        let isCurrentSSH = tabManager.selectedTab?.isSSH ?? false

        if openInNewTab || isCurrentSSH {
            guard let ws = tabManager.selectedWorkspace else { return }
            let tab = ws.createTab()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tab.terminalView?.sendText(command + "\n")
            }
        } else {
            // Run in current tab
            guard let tab = tabManager.selectedTab else { return }
            tab.terminalView?.sendText(command + "\n")
        }
    }
}

// MARK: - Unified bar button (all buttons same style)

struct BarButton: View {
    let label: String
    let dotColor: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isHovering ? dotColor : dotColor.opacity(0.4))
                    .frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundColor(isHovering ? dotColor : .white.opacity(0.4))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Rectangle()
                    .fill(isHovering ? dotColor.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
