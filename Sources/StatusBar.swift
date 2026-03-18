import AppKit
import SwiftUI

// MARK: - Design tokens (shared with ContentView)

private let sbBg      = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255)
private let sbAccent  = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255)
private let sbGreen   = Color(red: 0x00/255, green: 0xFF/255, blue: 0x88/255)
private let sbCyan    = Color(red: 0x00/255, green: 0xDD/255, blue: 0xFF/255)
private let sbDim     = Color.white.opacity(0.35)
private let sbBorder  = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255).opacity(0.3)

/// Bottom status bar — lightweight system info.
/// Updates on: tab switch, directory change, 10-second timer.
struct StatusBarView: View {
    @ObservedObject var tabManager: TabManager
    @State private var gitBranch: String = ""
    @State private var rosDistro: String = ""
    @State private var rosDomain: String = ""
    @State private var cpuUsage: String = ""
    @State private var memUsage: String = ""
    @State private var clock: String = ""
    @State private var cwd: String = "~"

    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // Left: ROS2 info
            if !rosDistro.isEmpty {
                statusDot(color: sbGreen)
                statusLabel("ROS2:", value: rosDistro, valueColor: sbGreen)
                separatorView
                statusLabel("DOMAIN:", value: rosDomain.isEmpty ? "0" : rosDomain, valueColor: sbAccent)
                separatorView
            }

            // Git branch
            if !gitBranch.isEmpty {
                Text("\u{2387}")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(sbDim)
                statusLabel("", value: gitBranch, valueColor: sbAccent)
                separatorView
            }

            // CWD
            Text(cwd)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(sbDim)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()

            // Right: system stats + clock
            statusLabel("CPU:", value: cpuUsage, valueColor: sbAccent)
            separatorView
            statusLabel("MEM:", value: memUsage, valueColor: sbAccent)
            separatorView
            Text(clock)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(sbDim)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .frame(minHeight: 22, maxHeight: 22)
        .background(sbBg)
        .overlay(alignment: .top) {
            Rectangle().fill(sbBorder).frame(height: 1)
        }
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
        .onReceive(clockTimer) { _ in updateClock() }
        .onChange(of: tabManager.selectedWorkspaceId) { _ in refresh() }
    }

    // MARK: - Subviews

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .padding(.trailing, 4)
    }

    private func statusLabel(_ label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 3) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(sbDim)
            }
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(valueColor)
        }
    }

    private var separatorView: some View {
        Text("|")
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.12))
            .padding(.horizontal, 6)
    }

    // MARK: - Data refresh

    private func refresh() {
        updateCwd()
        updateGitBranch()
        updateROS2()
        updateSystemStats()
        updateClock()
    }

    private func updateCwd() {
        let dir = tabManager.selectedTab?.currentDirectory
            ?? tabManager.selectedWorkspace?.directory
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) {
            let rel = String(dir.dropFirst(home.count))
            cwd = rel.isEmpty ? "~" : "~" + rel
        } else {
            cwd = dir
        }
    }

    private func updateGitBranch() {
        let dir = tabManager.selectedTab?.currentDirectory
            ?? tabManager.selectedWorkspace?.directory ?? ""
        // Walk up to find .git/HEAD
        var current = dir
        while !current.isEmpty && current != "/" {
            let headPath = current + "/.git/HEAD"
            if let content = try? String(contentsOfFile: headPath, encoding: .utf8) {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("ref: refs/heads/") {
                    gitBranch = String(trimmed.dropFirst("ref: refs/heads/".count))
                } else {
                    gitBranch = String(trimmed.prefix(8))
                }
                return
            }
            current = (current as NSString).deletingLastPathComponent
        }
        gitBranch = ""
    }

    private func updateROS2() {
        if let distro = ProcessInfo.processInfo.environment["ROS_DISTRO"] {
            rosDistro = distro
        } else {
            rosDistro = ""
        }
        rosDomain = ProcessInfo.processInfo.environment["ROS_DOMAIN_ID"] ?? ""
    }

    private func updateSystemStats() {
        // CPU via host_statistics (lightweight mach call)
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()

        let result = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let user = Double(loadInfo.cpu_ticks.0)
            let system = Double(loadInfo.cpu_ticks.1)
            let idle = Double(loadInfo.cpu_ticks.2)
            let total = user + system + idle
            if total > 0 {
                let usage = ((user + system) / total) * 100
                cpuUsage = String(format: "%.0f%%", usage)
            }
        }

        // Memory
        let totalMem = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalMem) / 1_073_741_824
        var vmStats = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &vmCount)
            }
        }

        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(vmStats.active_count) * pageSize
            let wired = UInt64(vmStats.wire_count) * pageSize
            let compressed = UInt64(vmStats.compressor_page_count) * pageSize
            let usedGB = Double(active + wired + compressed) / 1_073_741_824
            memUsage = String(format: "%.0fGB/%.0fGB", usedGB, totalGB)
        }
    }

    private func updateClock() {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        clock = fmt.string(from: Date())
    }
}
