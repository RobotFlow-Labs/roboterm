import AppKit

/// AppleScript-facing wrapper around a ROBOTERM window (TabManager).
///
/// ROBOTERM uses one TabManager per window. Each TabManager manages multiple workspaces,
/// each containing multiple tabs (terminals).
@MainActor
@objc(RobotermScriptWindow)
final class ScriptWindow: NSObject {
    let stableID: String
    private weak var tabManager: TabManager?

    init(tabManager: TabManager) {
        self.stableID = tabManager.window.map {
            "window-\(ObjectIdentifier($0).hashValue)"
        } ?? UUID().uuidString
        self.tabManager = tabManager
    }

    @objc(id)
    var idValue: String { stableID }

    @objc(title)
    var title: String {
        tabManager?.window?.title ?? "ROBOTERM"
    }

    @objc(tabs)
    var tabs: [ScriptTab] {
        guard let mgr = tabManager else { return [] }
        return mgr.workspaces.enumerated().map { (index, ws) in
            ScriptTab(window: self, workspace: ws, index: index + 1, tabManager: mgr)
        }
    }

    @objc(selectedTab)
    var selectedTab: ScriptTab? {
        guard let mgr = tabManager, let ws = mgr.selectedWorkspace else { return nil }
        let index = (mgr.workspaces.firstIndex(where: { $0.id == ws.id }) ?? 0) + 1
        return ScriptTab(window: self, workspace: ws, index: index, tabManager: mgr)
    }

    @objc(valueInTabsWithUniqueID:)
    func valueInTabs(uniqueID: String) -> ScriptTab? {
        tabs.first(where: { $0.idValue == uniqueID })
    }

    @objc(terminals)
    var terminals: [ScriptTerminal] {
        guard let mgr = tabManager else { return [] }
        return mgr.tabs.map { ScriptTerminal(tab: $0) }
    }

    @objc(valueInTerminalsWithUniqueID:)
    func valueInTerminals(uniqueID: String) -> ScriptTerminal? {
        guard let mgr = tabManager else { return nil }
        return mgr.tabs.first(where: { $0.id.uuidString == uniqueID }).map { ScriptTerminal(tab: $0) }
    }

    /// Handler for `activate window`.
    @objc(handleActivateWindowCommand:)
    func handleActivateWindow(_ command: NSScriptCommand) -> Any? {
        tabManager?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return nil
    }

    /// Handler for `close window`.
    @objc(handleCloseWindowCommand:)
    func handleCloseWindow(_ command: NSScriptCommand) -> Any? {
        tabManager?.window?.close()
        return nil
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appClassDescription = NSApplication.shared.classDescription as? NSScriptClassDescription else {
            return nil
        }
        return NSUniqueIDSpecifier(
            containerClassDescription: appClassDescription,
            containerSpecifier: nil,
            key: "scriptWindows",
            uniqueID: stableID
        )
    }
}
