import SwiftUI

// MARK: - Agent definitions

struct AgentDef {
    let name: String
    let icon: String      // SF Symbol or emoji
    let command: String   // CLI command to launch
    let color: Color
}

private let agents: [AgentDef] = [
    AgentDef(name: "claude", icon: "\u{2728}", command: "claude", color: Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255)),
    AgentDef(name: "codex", icon: "\u{2699}", command: "codex", color: Color(red: 0x00/255, green: 0xFF/255, blue: 0x88/255)),
]

// MARK: - Agent Launcher Bar

struct AgentBar: View {
    @ObservedObject var tabManager: TabManager

    private let barBg = Color(red: 0x0F/255, green: 0x0F/255, blue: 0x0F/255)
    private let borderColor = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255).opacity(0.15)

    var body: some View {
        HStack(spacing: 0) {
            // Settings gear
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 28, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Agent buttons
            ForEach(agents, id: \.name) { agent in
                AgentButton(agent: agent) {
                    launchAgent(agent)
                }
            }

            Spacer()

            // ROS2 quick-launch
            AgentQuickButton(label: "ros2", color: Color(red: 0x00/255, green: 0xFF/255, blue: 0x88/255)) {
                launchCommand("ros2 topic list")
            }

            AgentQuickButton(label: "docker", color: Color(red: 0x00/255, green: 0xDD/255, blue: 0xFF/255)) {
                launchCommand("docker compose ps")
            }
        }
        .padding(.horizontal, 4)
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
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? agent.color.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Quick button (for ROS2, Docker, etc.)

struct AgentQuickButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(isHovering ? color : .white.opacity(0.3))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isHovering ? color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
