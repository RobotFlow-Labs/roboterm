import AppKit
import SwiftUI

@main
struct RobotermApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Self.configureEnvironment()
    }

    var body: some Scene {
        // Window creation is handled by AppDelegate.
        // We use a hidden settings scene to satisfy the App protocol.
        Settings { EmptyView() }
    }

    /// Set up process-level environment variables that shells and ROBOTERM tools expect.
    private static func configureEnvironment() {
        // Use xterm-256color — SwiftTerm is fully compatible.
        if getenv("TERM") == nil {
            setenv("TERM", "xterm-256color", 1)
        }

        if getenv("TERM_PROGRAM") == nil {
            setenv("TERM_PROGRAM", "roboterm", 1)
        }

        // Let shells know they're running inside ROBOTERM.
        setenv("ROBOTERM", "1", 1)

        // Point to the tools script for auto-sourcing in shell profiles.
        if let toolsPath = Bundle.main.path(forResource: "roboterm-tools", ofType: "sh") {
            setenv("ROBOTERM_TOOLS", toolsPath, 1)
        } else {
            let paths = [
                "/Applications/ROBOTERM.app/Contents/Resources/roboterm-tools.sh",
                Bundle.main.bundlePath + "/Contents/Resources/scripts/roboterm-tools.sh",
            ]
            for path in paths where FileManager.default.fileExists(atPath: path) {
                setenv("ROBOTERM_TOOLS", path, 1)
                break
            }
        }
    }
}
