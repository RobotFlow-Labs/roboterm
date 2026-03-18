import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    /// All tab managers (one per window).
    private(set) var tabManagers: [TabManager] = []

    /// The tab manager for the currently focused window.
    var focusedTabManager: TabManager? {
        guard let keyWindow = NSApp.keyWindow else { return tabManagers.first }
        return tabManagers.first { $0.window === keyWindow }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Force Ghostty initialization
        _ = GhosttyManager.shared

        // Try to restore a previous session
        var restored = false
        if let session = SessionStore.restore() {
            restored = SessionStore.apply(session, to: self)
            if restored {
                SessionStore.clear()
            }
        }

        if !restored {
            createNewWindow()
        }

        // Build main menu
        NSApp.mainMenu = buildMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionStore.save(tabManagers: tabManagers)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Window management

    func registerTabManager(_ tabManager: TabManager) {
        tabManagers.append(tabManager)
    }

    func createWindowForTabManager(_ tabManager: TabManager) {
        if !tabManagers.contains(where: { $0 === tabManager }) {
            tabManagers.append(tabManager)
        }

        let contentView = ContentView(tabManager: tabManager)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.title = "ROBOTERM"
        window.backgroundColor = GhosttyManager.shared.backgroundColor
        window.isOpaque = GhosttyManager.shared.backgroundOpacity >= 1.0
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        window.zoom(nil)

        tabManager.window = window
    }

    func createNewWindow() {
        let tabManager = TabManager()
        createWindowForTabManager(tabManager)
    }

    // MARK: - Menu

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About ROBOTERM", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ROBOTERM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "New Tab", action: #selector(newTab(_:)), keyEquivalent: "t")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(closeTab(_:)), keyEquivalent: "w")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // View menu (splits)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Split Right", action: #selector(splitRight(_:)), keyEquivalent: "d")
        viewMenu.addItem(withTitle: "Split Down", action: #selector(splitDown(_:)), keyEquivalent: "d")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Next Pane", action: #selector(nextPane(_:)), keyEquivalent: "]")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(withTitle: "Previous Pane", action: #selector(previousPane(_:)), keyEquivalent: "[")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Next Tab", action: #selector(nextTab(_:)), keyEquivalent: "}")
        windowMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(withTitle: "Previous Tab", action: #selector(previousTab(_:)), keyEquivalent: "{")
        windowMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(.separator())
        for i in 1...9 {
            windowMenu.addItem(withTitle: "Tab \(i)", action: #selector(selectTabByNumber(_:)), keyEquivalent: "\(i)")
            windowMenu.items.last?.tag = i
        }
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // Edit menu (for Copy/Paste to work)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Robotics menu
        let roboticsMenu = NSMenu(title: "Robotics")

        // ROS2 section
        roboticsMenu.addItem(withTitle: "ROS2 Node List", action: #selector(ros2NodeList(_:)), keyEquivalent: "")
        roboticsMenu.addItem(withTitle: "ROS2 Topic List", action: #selector(ros2TopicList(_:)), keyEquivalent: "")
        roboticsMenu.addItem(withTitle: "ROS2 Service List", action: #selector(ros2ServiceList(_:)), keyEquivalent: "")
        roboticsMenu.addItem(.separator())

        // Quick commands
        let ros2LaunchItem = NSMenuItem(title: "Launch...", action: nil, keyEquivalent: "")
        let launchSubmenu = NSMenu(title: "Launch")
        launchSubmenu.addItem(withTitle: "ros2 launch", action: #selector(ros2Launch(_:)), keyEquivalent: "l")
        launchSubmenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        launchSubmenu.addItem(withTitle: "ros2 bag record", action: #selector(ros2BagRecord(_:)), keyEquivalent: "")
        launchSubmenu.addItem(withTitle: "ros2 bag play", action: #selector(ros2BagPlay(_:)), keyEquivalent: "")
        ros2LaunchItem.submenu = launchSubmenu
        roboticsMenu.addItem(ros2LaunchItem)
        roboticsMenu.addItem(.separator())

        // Simulation
        let simItem = NSMenuItem(title: "Simulation", action: nil, keyEquivalent: "")
        let simSubmenu = NSMenu(title: "Simulation")
        simSubmenu.addItem(withTitle: "Gazebo", action: #selector(launchGazebo(_:)), keyEquivalent: "")
        simSubmenu.addItem(withTitle: "RViz2", action: #selector(launchRViz2(_:)), keyEquivalent: "")
        simSubmenu.addItem(withTitle: "MuJoCo", action: #selector(launchMuJoCo(_:)), keyEquivalent: "")
        simItem.submenu = simSubmenu
        roboticsMenu.addItem(simItem)
        roboticsMenu.addItem(.separator())

        // ANIMA section
        let animaItem = NSMenuItem(title: "ANIMA", action: nil, keyEquivalent: "")
        let animaSubmenu = NSMenu(title: "ANIMA")
        animaSubmenu.addItem(withTitle: "Module Status", action: #selector(animaStatus(_:)), keyEquivalent: "")
        animaSubmenu.addItem(withTitle: "docker compose up", action: #selector(animaComposeUp(_:)), keyEquivalent: "")
        animaSubmenu.addItem(withTitle: "docker compose down", action: #selector(animaComposeDown(_:)), keyEquivalent: "")
        animaSubmenu.addItem(.separator())
        animaSubmenu.addItem(withTitle: "View Logs", action: #selector(animaLogs(_:)), keyEquivalent: "")
        animaItem.submenu = animaSubmenu
        roboticsMenu.addItem(animaItem)
        roboticsMenu.addItem(.separator())

        // Hardware
        let hwItem = NSMenuItem(title: "Hardware", action: nil, keyEquivalent: "")
        let hwSubmenu = NSMenu(title: "Hardware")
        hwSubmenu.addItem(withTitle: "Camera Status", action: #selector(hwCamera(_:)), keyEquivalent: "")
        hwSubmenu.addItem(withTitle: "LiDAR Status", action: #selector(hwLidar(_:)), keyEquivalent: "")
        hwSubmenu.addItem(withTitle: "SSH to Robot...", action: #selector(hwSSH(_:)), keyEquivalent: "")
        hwItem.submenu = hwSubmenu
        roboticsMenu.addItem(hwItem)

        let roboticsMenuItem = NSMenuItem()
        roboticsMenuItem.submenu = roboticsMenu
        mainMenu.addItem(roboticsMenuItem)

        return mainMenu
    }

    // MARK: - Menu actions

    @objc private func newWindow(_ sender: Any?) {
        createNewWindow()
    }

    @objc private func newTab(_ sender: Any?) {
        focusedTabManager?.createTab()
    }

    @objc private func closeTab(_ sender: Any?) {
        guard let mgr = focusedTabManager, let tab = mgr.selectedTab else { return }
        mgr.closeTab(tab.id)
    }

    @objc private func nextTab(_ sender: Any?) {
        focusedTabManager?.selectNextTab()
    }

    @objc private func previousTab(_ sender: Any?) {
        focusedTabManager?.selectPreviousTab()
    }

    @objc private func splitRight(_ sender: Any?) {
        guard let mgr = focusedTabManager, let ws = mgr.selectedWorkspace, let tab = ws.selectedTab else { return }
        ws.createSplitTab(nextTo: tab.id, direction: .horizontal)
    }

    @objc private func splitDown(_ sender: Any?) {
        guard let mgr = focusedTabManager, let ws = mgr.selectedWorkspace, let tab = ws.selectedTab else { return }
        ws.createSplitTab(nextTo: tab.id, direction: .vertical)
    }

    @objc private func nextPane(_ sender: Any?) {
        guard let mgr = focusedTabManager, let ws = mgr.selectedWorkspace, let layout = ws.splitLayout else { return }
        let tabIds = layout.allTabIds
        guard tabIds.count > 1, let currentId = ws.selectedTabId,
              let index = tabIds.firstIndex(of: currentId) else { return }
        let nextId = tabIds[(index + 1) % tabIds.count]
        ws.selectedTabId = nextId
        if let tab = ws.tabs.first(where: { $0.id == nextId }) {
            tab.focus()
        }
    }

    @objc private func previousPane(_ sender: Any?) {
        guard let mgr = focusedTabManager, let ws = mgr.selectedWorkspace, let layout = ws.splitLayout else { return }
        let tabIds = layout.allTabIds
        guard tabIds.count > 1, let currentId = ws.selectedTabId,
              let index = tabIds.firstIndex(of: currentId) else { return }
        let prevId = tabIds[(index - 1 + tabIds.count) % tabIds.count]
        ws.selectedTabId = prevId
        if let tab = ws.tabs.first(where: { $0.id == prevId }) {
            tab.focus()
        }
    }

    @objc private func selectTabByNumber(_ sender: NSMenuItem) {
        guard let mgr = focusedTabManager, let ws = mgr.selectedWorkspace else { return }
        let index = sender.tag - 1
        if sender.tag == 9 {
            // Cmd+9 = last tab
            if let last = ws.tabs.last { ws.selectTab(last.id) }
        } else if index >= 0, index < ws.tabs.count {
            ws.selectTab(ws.tabs[index].id)
        }
    }

    // MARK: - Robotics menu actions

    private func runCommandInNewTab(_ command: String) {
        guard let mgr = focusedTabManager else { return }
        let tab = mgr.createTab()
        // Send command after terminal initializes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let surface = tab.terminalView?.surface {
                let cmd = command + "\n"
                cmd.withCString { ptr in
                    ghostty_surface_text(surface, ptr, UInt(cmd.utf8.count))
                }
            }
        }
    }

    @objc private func ros2NodeList(_ sender: Any?) { runCommandInNewTab("ros2 node list") }
    @objc private func ros2TopicList(_ sender: Any?) { runCommandInNewTab("ros2 topic list") }
    @objc private func ros2ServiceList(_ sender: Any?) { runCommandInNewTab("ros2 service list") }
    @objc private func ros2Launch(_ sender: Any?) { runCommandInNewTab("ros2 launch ") }
    @objc private func ros2BagRecord(_ sender: Any?) { runCommandInNewTab("ros2 bag record -a") }
    @objc private func ros2BagPlay(_ sender: Any?) { runCommandInNewTab("ros2 bag play ") }
    @objc private func launchGazebo(_ sender: Any?) { runCommandInNewTab("gz sim") }
    @objc private func launchRViz2(_ sender: Any?) { runCommandInNewTab("rviz2") }
    @objc private func launchMuJoCo(_ sender: Any?) { runCommandInNewTab("python3 -m mujoco.viewer") }
    @objc private func animaStatus(_ sender: Any?) { runCommandInNewTab("docker compose ps") }
    @objc private func animaComposeUp(_ sender: Any?) { runCommandInNewTab("docker compose up -d") }
    @objc private func animaComposeDown(_ sender: Any?) { runCommandInNewTab("docker compose down") }
    @objc private func animaLogs(_ sender: Any?) { runCommandInNewTab("docker compose logs -f --tail=50") }
    @objc private func hwCamera(_ sender: Any?) { runCommandInNewTab("ros2 topic echo /camera/image_raw --once") }
    @objc private func hwLidar(_ sender: Any?) { runCommandInNewTab("ros2 topic echo /scan --once") }
    @objc private func hwSSH(_ sender: Any?) { runCommandInNewTab("ssh ") }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        tabManagers.removeAll { $0.window === window }
    }
}
