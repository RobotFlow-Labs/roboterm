import AppKit
import IOKit
import IOKit.usb
import Network
import SwiftUI

// MARK: - USB Hotplug Monitor

/// Runs on a dedicated background thread with its own CFRunLoop so that
/// IOKit matching notifications fire independently of the main run loop.
final class USBHotplugMonitor {
    static let shared = USBHotplugMonitor()

    var onConnect: ((String) -> Void)?
    var onDisconnect: ((String) -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private var runLoop: CFRunLoop?
    private let thread: Thread

    // Stash self pointer so C callbacks can reach it.
    private var selfPtr: UnsafeMutableRawPointer?

    private init() {
        // Thread is set up in start() — just create a placeholder here.
        thread = Thread()
    }

    func start() {
        let t = Thread {
            self.runMonitor()
        }
        t.name = "roboterm.usb.hotplug"
        t.qualityOfService = .utility
        t.start()
    }

    private func runMonitor() {
        runLoop = CFRunLoopGetCurrent()

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port

        let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(runLoop, source, .defaultMode)

        // Retain self for C callback context — balanced in deinit.
        selfPtr = Unmanaged.passRetained(self).toOpaque()

        // --- Matched (connect) notification ---
        let matchConnectCB: IOServiceMatchingCallback = { (refCon, iterator) in
            guard let ctx = refCon else { return }
            let monitor = Unmanaged<USBHotplugMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.drainIterator(iterator, connected: true)
        }

        IOServiceAddMatchingNotification(
            port,
            kIOMatchedNotification,
            IOServiceMatching("IOUSBHostDevice"),
            matchConnectCB,
            selfPtr,
            &matchedIterator
        )

        // Drain existing-at-startup devices so IOKit arms future notifications.
        // We do NOT call onConnect for these — HardwareState.init() handles
        // the initial population via enumerateUSBDevices().
        drainIterator(matchedIterator, connected: false)

        // --- Terminated (disconnect) notification ---
        let matchTermCB: IOServiceMatchingCallback = { (refCon, iterator) in
            guard let ctx = refCon else { return }
            let monitor = Unmanaged<USBHotplugMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.drainIterator(iterator, connected: false)
        }

        IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            IOServiceMatching("IOUSBHostDevice"),
            matchTermCB,
            selfPtr,
            &terminatedIterator
        )
        drainIterator(terminatedIterator, connected: false)

        // Run until cancelled.
        CFRunLoopRun()

        // Cleanup if run loop exits.
        if matchedIterator != 0 { IOObjectRelease(matchedIterator) }
        if terminatedIterator != 0 { IOObjectRelease(terminatedIterator) }
        IONotificationPortDestroy(port)
        if let ptr = selfPtr {
            Unmanaged<USBHotplugMonitor>.fromOpaque(ptr).release()
        }
    }

    private func drainIterator(_ iterator: io_iterator_t, connected: Bool) {
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer { IOObjectRelease(entry) }
            let name = usbProductName(from: entry)
            if !name.isEmpty {
                if connected {
                    DispatchQueue.main.async { self.onConnect?(name) }
                } else {
                    DispatchQueue.main.async { self.onDisconnect?(name) }
                }
            }
            entry = IOIteratorNext(iterator)
        }
    }

    private func usbProductName(from entry: io_object_t) -> String {
        guard let cf = IORegistryEntryCreateCFProperty(
            entry, "USB Product Name" as CFString, kCFAllocatorDefault, 0
        ) else { return "" }
        return (cf.takeRetainedValue() as? String) ?? ""
    }

    deinit {
        if let rl = runLoop { CFRunLoopStop(rl) }
    }
}

// Design tokens: use RF namespace from DesignTokens.swift

// MARK: - Device model

struct HardwareDevice: Identifiable {
    let id: String        // stable ID based on name
    let name: String
    let type: DeviceType
    var status: DeviceStatus
    let detail: String

    enum DeviceType: String, Codable {
        case camera, lidar, imu, compute, gamepad, serial
    }

    enum DeviceStatus {
        case connected, disconnected
    }

    init(name: String, type: DeviceType, status: DeviceStatus, detail: String) {
        self.id = name
        self.name = name
        self.type = type
        self.status = status
        self.detail = detail
    }
}

// MARK: - Network host config (loaded from ~/.config/roboterm/hosts.json)

struct NetworkHost: Codable {
    let name: String
    let host: String       // IP or hostname
    let type: String       // "jetson", "rpi", "server", "robot"
}

// MARK: - Hardware state (persists across SwiftUI redraws)

@MainActor
final class HardwareState: ObservableObject {
    static let shared = HardwareState()

    @Published var devices: [HardwareDevice] = []
    @Published var isScanning = false

    private let scanQueue = DispatchQueue(label: "roboterm.hardware.scan")
    private var timer: Timer?

    deinit {
        timer?.invalidate()
    }

    private init() {
        // Run initial scan — populate with what we can detect
        let initial = HardwarePanel.detectDevices()

        // Always include MacBook Camera on Apple Silicon
        var devices = initial
        #if arch(arm64)
        if !devices.contains(where: { $0.name == "MacBook Camera" }) {
            devices.insert(HardwareDevice(name: "MacBook Camera", type: .camera, status: .connected, detail: "Built-in FaceTime Camera"), at: 0)
        }
        #endif

        // Always include configured network hosts (show as disconnected until verified)
        let hosts = HardwarePanel.loadNetworkHosts()
        for host in hosts where !devices.contains(where: { $0.name == host.name }) {
            devices.append(HardwareDevice(
                name: host.name, type: .compute,
                status: .disconnected, detail: "\(host.type) (\(host.host))"
            ))
        }

        self.devices = devices

        // Wire up IOKit hotplug notifications
        USBHotplugMonitor.shared.onConnect = { [weak self] name in
            guard let self else { return }
            // Classify and insert/update the device
            let device = HardwarePanel.classifyUSBDevice(name: name)
            if let idx = self.devices.firstIndex(where: { $0.name == name }) {
                self.devices[idx] = HardwareDevice(
                    name: name, type: self.devices[idx].type,
                    status: .connected, detail: self.devices[idx].detail
                )
            } else {
                self.devices.append(device)
                self.sortDevices()
            }
        }

        USBHotplugMonitor.shared.onDisconnect = { [weak self] name in
            guard let self else { return }
            if let idx = self.devices.firstIndex(where: { $0.name == name }) {
                let old = self.devices[idx]
                self.devices[idx] = HardwareDevice(
                    name: old.name, type: old.type,
                    status: .disconnected, detail: old.detail
                )
                self.sortDevices()
            }
        }

        USBHotplugMonitor.shared.start()

        // Then schedule periodic background scans for network host reachability
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard SidebarVisibility.shared.isVisible else { return }
                self?.scan()
            }
        }
    }

    private func sortDevices() {
        devices.sort { a, b in
            if a.status != b.status { return a.status == .connected }
            if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
            return a.name < b.name
        }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        let currentDevices = self.devices

        // Use a thread with its own RunLoop so Process works correctly
        let thread = Thread {
            let found = HardwarePanel.detectDevices()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // If scan found nothing but we had devices before, keep old state
                if found.isEmpty && !currentDevices.isEmpty {
                    self.isScanning = false
                    return
                }

                var registry: [String: HardwareDevice] = [:]
                for device in currentDevices {
                    registry[device.name] = HardwareDevice(
                        name: device.name, type: device.type,
                        status: .disconnected, detail: device.detail
                    )
                }
                for device in found {
                    registry[device.name] = HardwareDevice(
                        name: device.name, type: device.type,
                        status: device.status, detail: device.detail
                    )
                }
                let sorted = registry.values.sorted { a, b in
                    if a.status != b.status { return a.status == .connected }
                    if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
                    return a.name < b.name
                }

                self.devices = Array(sorted)
                self.isScanning = false
            }
        }
        thread.qualityOfService = .utility
        thread.start()
    }
}

// MARK: - Hardware detection utilities (namespace)

enum HardwarePanel {

    // MARK: - Auto-detect all hardware

    static func detectDevices() -> [HardwareDevice] {
        var results: [HardwareDevice] = []

        // 1. Built-in camera — always present on MacBook
        #if arch(arm64)
        results.append(HardwareDevice(
            name: "MacBook Camera", type: .camera, status: .connected,
            detail: "Built-in FaceTime Camera"
        ))
        #endif

        // 2. USB devices via IOKit
        for productName in enumerateUSBDevices() {
            // Skip HID sub-interfaces, hubs, and monitor controls — they add
            // noise without being meaningful robotics hardware.
            if productName.contains("HID") || productName.contains("Hub") ||
               productName.contains("Monitor") || productName.contains("Controls") { continue }

            let device = HardwarePanel.classifyUSBDevice(name: productName)
            if !results.contains(where: { $0.name == device.name }) {
                results.append(device)
            }
        }

        // 3. Serial ports via FileManager (no subprocess)
        if let devContents = try? FileManager.default.contentsOfDirectory(atPath: "/dev") {
            for entry in devContents where (entry.hasPrefix("tty.usb") || entry.hasPrefix("cu.usb")) {
                if !results.contains(where: { $0.name == entry }) {
                    results.append(HardwareDevice(
                        name: entry, type: .serial, status: .connected, detail: "/dev/\(entry)"
                    ))
                }
            }
        }

        // 4. Network hosts from config file (~/.config/roboterm/hosts.json)
        // Ping each host (skipped if scan is too slow — will be checked next cycle)
        let hosts = loadNetworkHosts()
        for host in hosts {
            // Add to results regardless — scan merge will handle status
            let reachable = canReachHost(host.host)
            results.append(HardwareDevice(
                name: host.name, type: .compute,
                status: reachable ? .connected : .disconnected,
                detail: "\(host.type) (\(host.host))"
            ))
        }

        return results
    }

    // MARK: - USB device classification

    /// Classify a USB product name string into a typed HardwareDevice.
    /// Shared between the initial scan and hotplug connect callbacks.
    static func classifyUSBDevice(name productName: String) -> HardwareDevice {
        if productName.contains("ZED") || productName.contains("Stereolabs") {
            return HardwareDevice(name: productName, type: .camera, status: .connected, detail: "Stereolabs Depth Camera")
        } else if productName.contains("RealSense") {
            return HardwareDevice(name: productName, type: .camera, status: .connected, detail: "Intel Depth Camera")
        } else if productName.contains("Webcam") || productName.contains("Camera") || productName.contains("Cam") {
            return HardwareDevice(name: productName, type: .camera, status: .connected, detail: "USB Camera")
        } else if productName.contains("Velodyne") || productName.contains("Ouster") ||
                  productName.contains("Livox") || productName.contains("RPLIDAR") ||
                  productName.contains("Hokuyo") || productName.contains("LiDAR") {
            return HardwareDevice(name: productName, type: .lidar, status: .connected, detail: "LiDAR Sensor")
        } else if productName.contains("IMU") || productName.contains("Bosch") ||
                  productName.contains("ICM") || productName.contains("MPU") {
            return HardwareDevice(name: productName, type: .imu, status: .connected, detail: "Inertial Measurement Unit")
        } else if productName.contains("Joystick") || productName.contains("Gamepad") ||
                  productName.contains("Controller") || productName.contains("Xbox") ||
                  productName.contains("DualSense") {
            return HardwareDevice(name: productName, type: .gamepad, status: .connected, detail: "Game Controller")
        } else {
            return HardwareDevice(name: productName, type: .serial, status: .connected, detail: "USB Device")
        }
    }

    // MARK: - Network hosts config

    /// Load network hosts from ~/.config/roboterm/hosts.json
    /// Format: [{"name": "JETSON", "host": "jetson.local", "type": "jetson"}, ...]
    static func loadNetworkHosts() -> [NetworkHost] {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/roboterm")
        let hostsFile = configDir.appendingPathComponent("hosts.json")

        // Create default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: hostsFile.path) {
            let defaultHosts: [NetworkHost] = [
                NetworkHost(name: "JETSON", host: "jetson.local", type: "jetson"),
                NetworkHost(name: "ANIMA-MOTHER", host: "192.168.1.110", type: "server"),
            ]
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(defaultHosts) {
                try? data.write(to: hostsFile)
            }
            return defaultHosts
        }

        guard let data = try? Data(contentsOf: hostsFile),
              let hosts = try? JSONDecoder().decode([NetworkHost].self, from: data) else {
            return []
        }
        return hosts
    }

    // MARK: - IOKit USB enumeration

    /// Enumerates connected USB devices using IOKit directly.
    ///
    /// On macOS 13+ / Apple Silicon all USB devices are registered under the
    /// `IOUSBHostDevice` class. `IOUSBDevice` is a legacy alias that may not
    /// exist on ARM hardware, so we query `IOUSBHostDevice` exclusively to
    /// avoid empty or duplicate results.
    ///
    /// Falls back to `/usr/sbin/ioreg` (absolute path — required when running
    /// from an .app bundle where $PATH is not set) only if the IOKit call
    /// returns an empty set, which should never happen in practice.
    static func enumerateUSBDevices() -> [String] {
        var names: [String] = []

        // IOUSBHostDevice is the canonical class on macOS 12+ and all Apple
        // Silicon hardware. IOServiceMatching consumes (releases) the returned
        // dictionary, so we must not release it ourselves.
        var iterator: io_iterator_t = 0
        guard let matchingDict = IOServiceMatching("IOUSBHostDevice") else {
            return ioregsSubprocessFallback()
        }

        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard kr == KERN_SUCCESS, iterator != 0 else {
            return ioregsSubprocessFallback()
        }

        var device: io_object_t = IOIteratorNext(iterator)
        while device != 0 {
            if let cf = IORegistryEntryCreateCFProperty(
                device, "USB Product Name" as CFString, kCFAllocatorDefault, 0
            ) {
                if let name = cf.takeRetainedValue() as? String, !name.isEmpty {
                    if !names.contains(name) { names.append(name) }
                }
            }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        // If IOUSBHostDevice returned nothing (unexpected — maybe an older
        // Intel Mac running macOS 12 with the legacy stack), fall back to the
        // subprocess. Using absolute path because .app bundles don't get /usr/sbin
        // in $PATH from launchd.
        if names.isEmpty {
            return ioregsSubprocessFallback()
        }

        return names
    }

    /// Last-resort fallback: parse `ioreg` output.
    /// Uses an absolute path so it works from within an .app bundle.
    private static func ioregsSubprocessFallback() -> [String] {
        var names: [String] = []
        // Absolute path required — /usr/sbin is not in PATH for .app bundles.
        guard let output = runShell("/usr/sbin/ioreg -p IOUSB -l") else { return names }
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let start = trimmed.range(of: "\"USB Product Name\" = \"") else { continue }
            let rest = trimmed[start.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else { continue }
            let name = String(rest[..<end])
            if !name.isEmpty && !names.contains(name) { names.append(name) }
        }
        return names
    }

    // MARK: - Shell helpers

    private static func runShell(_ command: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        do {
            try task.run()
            // Kill after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if task.isRunning { task.terminate() }
            }
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            return (output?.isEmpty ?? true) ? nil : output
        } catch {
            return nil
        }
    }

    private static func canReachHost(_ host: String) -> Bool {
        // Use Network.framework — fast TCP probe, no subprocess
        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false

        let nwHost = NWEndpoint.Host(host)
        let connection = NWConnection(host: nwHost, port: 22, using: .tcp) // SSH port
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                reachable = true
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            case .waiting:
                // Host not reachable
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue.global(qos: .utility))

        // 1.5 second timeout
        _ = semaphore.wait(timeout: .now() + 1.5)
        connection.cancel()

        return reachable
    }
}

// MARK: - Hardware Panel View (collapsible, same style as Docker panel)

struct HardwarePanelView: View {
    @ObservedObject private var state = HardwareState.shared
    @State private var isExpanded: Bool = UserDefaults.standard.object(forKey: "panelExpanded.hardware") as? Bool ?? true

    private var connectedCount: Int {
        state.devices.filter { $0.status == .connected }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clickable header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                UserDefaults.standard.set(isExpanded, forKey: "panelExpanded.hardware")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(RF.accent.opacity(0.5))
                        .frame(width: 10)

                    Text("HARDWARE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(RF.accent.opacity(0.8))
                        .tracking(1.5)

                    Spacer()

                    HStack(spacing: 3) {
                        Circle().fill(connectedCount > 0 ? RF.green : RF.dim).frame(width: 5, height: 5)
                        Text("\(connectedCount)/\(state.devices.count)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(connectedCount > 0 ? RF.green.opacity(0.7) : RF.dim)
                    }

                    Button(action: { state.scan() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                            .foregroundStyle(RF.dim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle().fill(RF.accent.opacity(0.15)).frame(height: 1)
                    .padding(.horizontal, 8)

                ForEach(state.devices) { device in
                    HardwareDeviceRow(device: device)
                }

                // System status footer
                Rectangle().fill(RF.accent.opacity(0.1)).frame(height: 1)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                HStack(spacing: 4) {
                    Circle().fill(connectedCount > 0 ? RF.green : RF.dim).frame(width: 5, height: 5)
                    Text(connectedCount > 0 ? "SYSTEM: ONLINE" : "SYSTEM: IDLE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(connectedCount > 0 ? RF.green.opacity(0.6) : RF.dim)
                        .tracking(0.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Hardware device row (same style as Docker container row)

private struct HardwareDeviceRow: View {
    let device: HardwareDevice
    @State private var isHovering = false

    private var statusColor: Color {
        device.status == .connected ? RF.green : RF.dim
    }

    private var typeColor: Color {
        switch device.type {
        case .camera: return RF.cyan
        case .lidar: return RF.accent
        case .imu: return RF.yellow
        case .compute: return RF.green
        case .gamepad, .serial: return RF.dim
        }
    }

    private var typeLabel: String {
        switch device.type {
        case .camera: return "CAM"
        case .lidar: return "LDR"
        case .imu: return "IMU"
        case .compute: return "SBC"
        case .gamepad: return "JOY"
        case .serial: return "USB"
        }
    }

    private var typeIcon: String {
        switch device.type {
        case .camera: return "camera"
        case .lidar: return "sensor.tag.radiowaves.forward"
        case .imu: return "gyroscope"
        case .compute: return "cpu"
        case .gamepad: return "gamecontroller"
        case .serial: return "cable.connector"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 6, height: 6)

            Image(systemName: typeIcon)
                .font(.system(size: 9))
                .foregroundStyle(device.status == .connected ? typeColor : RF.dim)
                .frame(width: 14)

            Text(device.name)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isHovering ? typeColor : (device.status == .connected ? .white.opacity(0.6) : RF.dim))
                .lineLimit(1)

            Spacer()

            Text(typeLabel)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(device.status == .connected ? typeColor.opacity(0.5) : RF.dim.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(isHovering ? typeColor.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .help(device.detail)
    }
}
