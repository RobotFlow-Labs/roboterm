import SwiftUI

// MARK: - SSH Connections sidebar panel

struct SSHPanelView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var settings = TerminalSettings.shared
    @State private var isExpanded: Bool = UserDefaults.standard.object(forKey: "panelExpanded.ssh") as? Bool ?? true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { isExpanded.toggle() }
                UserDefaults.standard.set(isExpanded, forKey: "panelExpanded.ssh")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 10)

                    Text("SSH CONNECTIONS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(RF.cyan)
                        .tracking(1)

                    Spacer()

                    Text("\(settings.sshConnections.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle().fill(RF.cyan.opacity(0.1)).frame(height: 1)
                    .padding(.horizontal, 8)

                if settings.sshConnections.isEmpty {
                    Text("No connections configured")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 1) {
                        ForEach(settings.sshConnections) { conn in
                            SSHConnectionRow(connection: conn) {
                                connectSSH(conn)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func connectSSH(_ conn: SSHConnectionConfig) {
        guard !conn.host.isEmpty else { return }
        let mgr = AppDelegate.shared?.focusedTabManager ?? tabManager
        mgr.createSSHTab(config: conn)
    }
}

struct SSHConnectionRow: View {
    let connection: SSHConnectionConfig
    let onConnect: () -> Void
    @State private var isHovering = false

    private var dotColor: Color {
        Color(nsColor: NSColor(hex: connection.colorHex) ?? .cyan)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(connection.label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))

                let subtitle = "\(connection.user.isEmpty ? "" : connection.user + "@")\(connection.host)"
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                }
            }

            Spacer()

            if isHovering {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 10))
                    .foregroundColor(dotColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onConnect() }
        .contextMenu {
            Button("Connect") { onConnect() }
            Divider()
            Button("Edit in Preferences") {
                AppDelegate.shared?.openPreferences(nil)
            }
        }
    }
}
