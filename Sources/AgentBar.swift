import SwiftUI

// MARK: - Agent definitions

struct AgentDef {
    let name: String
    let icon: String
    let command: String
    let color: Color
}

private let agents: [AgentDef] = [
    AgentDef(name: "claude", icon: "\u{2728}", command: "claude", color: Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255)),
    AgentDef(name: "codex", icon: "\u{2699}", command: "codex", color: Color(red: 0x00/255, green: 0xFF/255, blue: 0x88/255)),
]

private let rfAccent = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255)
private let rfGreen  = Color(red: 0x00/255, green: 0xFF/255, blue: 0x88/255)
private let rfCyan   = Color(red: 0x00/255, green: 0xDD/255, blue: 0xFF/255)
private let rfPurple = Color(red: 0x8B/255, green: 0x5C/255, blue: 0xFF/255)
private let rfYellow = Color(red: 0xFF/255, green: 0xB8/255, blue: 0x00/255)

// MARK: - Agent Launcher Bar

struct AgentBar: View {
    @ObservedObject var tabManager: TabManager

    private let barBg = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255)
    private let borderColor = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255).opacity(0.15)

    var body: some View {
        HStack(spacing: 0) {
            // Agent buttons
            ForEach(agents, id: \.name) { agent in
                AgentButton(agent: agent) {
                    launchAgent(agent)
                }
            }

            // Separator
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 14)
                .padding(.horizontal, 4)

            // ROS2 quick-launch tools
            AgentQuickButton(label: "nodes", color: rfGreen) {
                launchCommand("ros2 node list")
            }
            AgentQuickButton(label: "topics", color: rfGreen) {
                launchCommand("ros2 topic list -v")
            }
            AgentQuickButton(label: "services", color: rfGreen) {
                launchCommand("ros2 service list")
            }
            AgentQuickButton(label: "params", color: rfGreen) {
                launchCommand("ros2 param list")
            }

            // Separator
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 14)
                .padding(.horizontal, 4)

            // Sim & tools
            AgentQuickButton(label: "gazebo", color: rfCyan) {
                launchCommand("gz sim")
            }
            AgentQuickButton(label: "rviz2", color: rfPurple) {
                launchCommand("rviz2")
            }
            AgentQuickButton(label: "rqt", color: rfYellow) {
                launchCommand("rqt")
            }

            Spacer()

            // Right side: Docker + diagnostics
            AgentQuickButton(label: "doctor", color: rfYellow) {
                launchCommand("ros2 doctor --report")
            }
            AgentQuickButton(label: "docker", color: rfCyan) {
                launchCommand("docker compose ps")
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
        .background(barBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(borderColor).frame(height: 1)
        }
    }

    private func launchAgent(_ agent: AgentDef) {
        launchCommand(agent.command)
    }

    private func launchCommand(_ command: String) {
        guard let ws = tabManager.selectedWorkspace else { return }
        let tab = ws.createTab()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let surface = tab.terminalView?.surface {
                let cmd = command + "\n"
                cmd.withCString { ptr in
                    ghostty_surface_text(surface, ptr, UInt(cmd.utf8.count))
                }
            }
        }
    }
}

// MARK: - Agent button

struct AgentButton: View {
    let agent: AgentDef
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(agent.icon)
                    .font(.system(size: 10))
                Text(agent.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .foregroundColor(isHovering ? agent.color : .white.opacity(0.45))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Rectangle()
                    .fill(isHovering ? agent.color.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Quick button

struct AgentQuickButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(isHovering ? color : .white.opacity(0.25))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    Rectangle()
                        .stroke(isHovering ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
