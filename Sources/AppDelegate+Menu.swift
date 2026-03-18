import AppKit

// MARK: - Main menu construction (extracted from AppDelegate for lint compliance)

extension AppDelegate {

    func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About ROBOTERM", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Preferences…", action: #selector(openPreferences(_:)), keyEquivalent: ",")
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
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "New SSH Connection…", action: #selector(hwSSH(_:)), keyEquivalent: "k")
        fileMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Save Session…", action: #selector(saveNamedSession(_:)), keyEquivalent: "s")
        fileMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(withTitle: "Load Session…", action: #selector(loadNamedSession(_:)), keyEquivalent: "o")
        fileMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // View menu (splits)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Sidebar", action: #selector(toggleSidebar(_:)), keyEquivalent: "\\")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Split Right", action: #selector(splitRight(_:)), keyEquivalent: "d")
        viewMenu.addItem(withTitle: "Split Down", action: #selector(splitDown(_:)), keyEquivalent: "d")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(withTitle: "Close Pane", action: #selector(closePane(_:)), keyEquivalent: "w")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Next Pane", action: #selector(nextPane(_:)), keyEquivalent: "]")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(withTitle: "Previous Pane", action: #selector(previousPane(_:)), keyEquivalent: "[")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(zoomIn(_:)), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Reset Zoom", action: #selector(zoomReset(_:)), keyEquivalent: "0")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Toggle Fullscreen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command, .control]
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
        mainMenu.addItem(buildRoboticsMenuItem())

        return mainMenu
    }

    private func buildRoboticsMenuItem() -> NSMenuItem {
        let roboticsMenu = NSMenu(title: "Robotics")

        // ROS2 Introspection
        let ros2IntrospectItem = NSMenuItem(title: "ROS2 Introspect", action: nil, keyEquivalent: "")
        let ros2IntrospectMenu = NSMenu(title: "ROS2 Introspect")
        ros2IntrospectMenu.addItem(withTitle: "Node List", action: #selector(ros2NodeList(_:)), keyEquivalent: "")
        ros2IntrospectMenu.addItem(withTitle: "Topic List (verbose)", action: #selector(ros2TopicList(_:)), keyEquivalent: "")
        ros2IntrospectMenu.addItem(withTitle: "Service List", action: #selector(ros2ServiceList(_:)), keyEquivalent: "")
        ros2IntrospectMenu.addItem(withTitle: "Action List", action: #selector(ros2ActionList(_:)), keyEquivalent: "")
        ros2IntrospectMenu.addItem(withTitle: "Parameter List", action: #selector(ros2ParamList(_:)), keyEquivalent: "")
        ros2IntrospectMenu.addItem(withTitle: "Interface List", action: #selector(ros2InterfaceList(_:)), keyEquivalent: "")
        ros2IntrospectMenu.addItem(.separator())
        ros2IntrospectMenu.addItem(withTitle: "Node Graph (rqt_graph)", action: #selector(ros2Graph(_:)), keyEquivalent: "")
        ros2IntrospectItem.submenu = ros2IntrospectMenu
        roboticsMenu.addItem(ros2IntrospectItem)

        // ROS2 Diagnostics
        let ros2DiagItem = NSMenuItem(title: "ROS2 Diagnostics", action: nil, keyEquivalent: "")
        let ros2DiagMenu = NSMenu(title: "ROS2 Diagnostics")
        ros2DiagMenu.addItem(withTitle: "Doctor Report", action: #selector(ros2Doctor(_:)), keyEquivalent: "")
        ros2DiagMenu.addItem(withTitle: "Daemon Status", action: #selector(ros2DaemonStatus(_:)), keyEquivalent: "")
        ros2DiagMenu.addItem(withTitle: "Multicast Test", action: #selector(ros2Multicast(_:)), keyEquivalent: "")
        ros2DiagMenu.addItem(withTitle: "wtf (diagnostic dump)", action: #selector(ros2Wtf(_:)), keyEquivalent: "")
        ros2DiagMenu.addItem(.separator())
        ros2DiagMenu.addItem(withTitle: "Topic Hz /scan", action: #selector(ros2HzScan(_:)), keyEquivalent: "")
        ros2DiagMenu.addItem(withTitle: "Topic Hz /camera/image_raw", action: #selector(ros2HzCamera(_:)), keyEquivalent: "")
        ros2DiagMenu.addItem(withTitle: "Topic Delay /tf", action: #selector(ros2DelayTf(_:)), keyEquivalent: "")
        ros2DiagItem.submenu = ros2DiagMenu
        roboticsMenu.addItem(ros2DiagItem)

        // ROS2 Transforms
        let ros2TfItem = NSMenuItem(title: "ROS2 Transforms", action: nil, keyEquivalent: "")
        let ros2TfMenu = NSMenu(title: "ROS2 Transforms")
        ros2TfMenu.addItem(withTitle: "TF Tree (view_frames)", action: #selector(ros2TfTree(_:)), keyEquivalent: "")
        ros2TfMenu.addItem(withTitle: "TF Echo base_link → map", action: #selector(ros2TfEcho(_:)), keyEquivalent: "")
        ros2TfMenu.addItem(withTitle: "TF Monitor", action: #selector(ros2TfMonitor(_:)), keyEquivalent: "")
        ros2TfItem.submenu = ros2TfMenu
        roboticsMenu.addItem(ros2TfItem)
        roboticsMenu.addItem(.separator())

        // Launch & Run
        let launchItem = NSMenuItem(title: "Launch & Run", action: nil, keyEquivalent: "")
        let launchMenu = NSMenu(title: "Launch & Run")
        launchMenu.addItem(withTitle: "ros2 launch...", action: #selector(ros2Launch(_:)), keyEquivalent: "l")
        launchMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        launchMenu.addItem(withTitle: "ros2 run...", action: #selector(ros2Run(_:)), keyEquivalent: "")
        launchMenu.addItem(.separator())
        launchMenu.addItem(withTitle: "colcon build", action: #selector(colconBuild(_:)), keyEquivalent: "b")
        launchMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        launchMenu.addItem(withTitle: "colcon build --packages-select...", action: #selector(colconBuildSelect(_:)), keyEquivalent: "")
        launchMenu.addItem(withTitle: "colcon test", action: #selector(colconTest(_:)), keyEquivalent: "")
        launchItem.submenu = launchMenu
        roboticsMenu.addItem(launchItem)

        // Bag Recording
        let bagItem = NSMenuItem(title: "Bag Recording", action: nil, keyEquivalent: "")
        let bagMenu = NSMenu(title: "Bag Recording")
        bagMenu.addItem(withTitle: "Record All Topics", action: #selector(ros2BagRecord(_:)), keyEquivalent: "")
        bagMenu.addItem(withTitle: "Record Select Topics...", action: #selector(ros2BagRecordSelect(_:)), keyEquivalent: "")
        bagMenu.addItem(withTitle: "Play Bag...", action: #selector(ros2BagPlay(_:)), keyEquivalent: "")
        bagMenu.addItem(withTitle: "Bag Info...", action: #selector(ros2BagInfo(_:)), keyEquivalent: "")
        bagItem.submenu = bagMenu
        roboticsMenu.addItem(bagItem)
        roboticsMenu.addItem(.separator())

        // Simulation
        let simItem = NSMenuItem(title: "Simulation", action: nil, keyEquivalent: "")
        let simMenu = NSMenu(title: "Simulation")
        simMenu.addItem(withTitle: "Gazebo Sim", action: #selector(launchGazebo(_:)), keyEquivalent: "")
        simMenu.addItem(withTitle: "RViz2", action: #selector(launchRViz2(_:)), keyEquivalent: "")
        simMenu.addItem(withTitle: "rqt", action: #selector(launchRqt(_:)), keyEquivalent: "")
        simMenu.addItem(withTitle: "MuJoCo", action: #selector(launchMuJoCo(_:)), keyEquivalent: "")
        simMenu.addItem(withTitle: "Isaac Sim", action: #selector(launchIsaacSim(_:)), keyEquivalent: "")
        simItem.submenu = simMenu
        roboticsMenu.addItem(simItem)
        roboticsMenu.addItem(.separator())

        // Docker
        let dockerItem = NSMenuItem(title: "Docker", action: nil, keyEquivalent: "")
        let dockerMenu = NSMenu(title: "Docker")
        dockerMenu.addItem(withTitle: "docker compose ps", action: #selector(dockerPs(_:)), keyEquivalent: "")
        dockerMenu.addItem(withTitle: "docker compose up -d", action: #selector(animaComposeUp(_:)), keyEquivalent: "")
        dockerMenu.addItem(withTitle: "docker compose down", action: #selector(animaComposeDown(_:)), keyEquivalent: "")
        dockerMenu.addItem(withTitle: "docker compose logs -f", action: #selector(animaLogs(_:)), keyEquivalent: "")
        dockerMenu.addItem(.separator())
        dockerMenu.addItem(withTitle: "docker ps", action: #selector(dockerPsAll(_:)), keyEquivalent: "")
        dockerMenu.addItem(withTitle: "docker images", action: #selector(dockerImages(_:)), keyEquivalent: "")
        dockerItem.submenu = dockerMenu
        roboticsMenu.addItem(dockerItem)

        // ANIMA
        let animaItem = NSMenuItem(title: "ANIMA Suite", action: nil, keyEquivalent: "")
        let animaMenu = NSMenu(title: "ANIMA Suite")
        animaMenu.addItem(withTitle: "Module Status", action: #selector(animaStatus(_:)), keyEquivalent: "")
        animaMenu.addItem(withTitle: "ANIMA Compile", action: #selector(animaCompile(_:)), keyEquivalent: "")
        animaMenu.addItem(withTitle: "ANIMA Plug", action: #selector(animaPlug(_:)), keyEquivalent: "")
        animaItem.submenu = animaMenu
        roboticsMenu.addItem(animaItem)
        roboticsMenu.addItem(.separator())

        // Hardware
        let hwItem = NSMenuItem(title: "Hardware", action: nil, keyEquivalent: "")
        let hwMenu = NSMenu(title: "Hardware")
        hwMenu.addItem(withTitle: "Camera Status", action: #selector(hwCamera(_:)), keyEquivalent: "")
        hwMenu.addItem(withTitle: "LiDAR Status", action: #selector(hwLidar(_:)), keyEquivalent: "")
        hwMenu.addItem(withTitle: "IMU Status", action: #selector(hwImu(_:)), keyEquivalent: "")
        hwMenu.addItem(withTitle: "Joy/Gamepad", action: #selector(hwJoy(_:)), keyEquivalent: "")
        hwMenu.addItem(.separator())
        hwMenu.addItem(withTitle: "USB Devices (system_profiler)", action: #selector(hwUsb(_:)), keyEquivalent: "")
        hwMenu.addItem(withTitle: "Serial Ports", action: #selector(hwSerial(_:)), keyEquivalent: "")
        hwMenu.addItem(.separator())
        // SSH connections submenu (populated from settings)
        let sshConnections = TerminalSettings.shared.sshConnections
        if sshConnections.isEmpty {
            hwMenu.addItem(withTitle: "SSH to Robot...", action: #selector(hwSSH(_:)), keyEquivalent: "")
        } else {
            let sshSubItem = NSMenuItem(title: "SSH Connections", action: nil, keyEquivalent: "")
            let sshSubMenu = NSMenu(title: "SSH Connections")
            for conn in sshConnections where !conn.host.isEmpty {
                let label = "\(conn.label) (\(conn.user.isEmpty ? conn.host : "\(conn.user)@\(conn.host)"))"
                let item = NSMenuItem(title: label, action: #selector(connectSSHFromMenu(_:)), keyEquivalent: "")
                item.representedObject = conn
                sshSubMenu.addItem(item)
            }
            sshSubMenu.addItem(.separator())
            sshSubMenu.addItem(withTitle: "Manage Connections…", action: #selector(openPreferences(_:)), keyEquivalent: "")
            sshSubItem.submenu = sshSubMenu
            hwMenu.addItem(sshSubItem)
        }
        hwItem.submenu = hwMenu
        roboticsMenu.addItem(hwItem)

        let roboticsMenuItem = NSMenuItem()
        roboticsMenuItem.submenu = roboticsMenu
        return roboticsMenuItem
    }
}
