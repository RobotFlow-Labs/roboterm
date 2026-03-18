import AppKit

/// AppleScript-facing wrapper around a ROBOTERM workspace (treated as a "tab").
///
/// Each workspace in the sidebar maps to one AppleScript tab.
@MainActor
@objc(RobotermScriptTab)
final class ScriptTab: NSObject {
    private weak var window: ScriptWindow?
    private weak var workspace: Workspace?
    private weak var tabManager: TabManager?
    private let tabIndex: Int

    init(window: ScriptWindow, workspace: Workspace, index: Int, tabManager: TabManager) {
        self.window = window
        self.workspace = workspace
        self.tabIndex = index
        self.tabManager = tabManager
    }

    @objc(id)
    var idValue: String {
        workspace?.id.uuidString ?? ""
    }

    @objc(title)
    var title: String {
        workspace?.displayName ?? ""
    }

    @objc(index)
    var index: Int { tabIndex }

    @objc(selected)
    var selected: Bool {
        guard let ws = workspace, let mgr = tabManager else { return false }
        return mgr.selectedWorkspaceId == ws.id
    }

    @objc(focusedTerminal)
    var focusedTerminal: ScriptTerminal? {
        guard let ws = workspace, let tab = ws.selectedTab else { return nil }
        return ScriptTerminal(tab: tab)
    }

    @objc(terminals)
    var terminals: [ScriptTerminal] {
        guard let ws = workspace else { return [] }
        return ws.tabs.map { ScriptTerminal(tab: $0) }
    }

    @objc(valueInTerminalsWithUniqueID:)
    func valueInTerminals(uniqueID: String) -> ScriptTerminal? {
        guard let ws = workspace else { return nil }
        return ws.tabs.first(where: { $0.id.uuidString == uniqueID }).map { ScriptTerminal(tab: $0) }
    }

    /// Handler for `select tab`.
    @objc(handleSelectTabCommand:)
    func handleSelectTab(_ command: NSScriptCommand) -> Any? {
        guard let ws = workspace, let mgr = tabManager else {
            command.scriptErrorNumber = errAEEventFailed
            command.scriptErrorString = "Tab is no longer available."
            return nil
        }
        mgr.selectWorkspace(ws.id)
        mgr.window?.makeKeyAndOrderFront(nil)
        return nil
    }

    /// Handler for `close tab`.
    @objc(handleCloseTabCommand:)
    func handleCloseTab(_ command: NSScriptCommand) -> Any? {
        guard let ws = workspace, let mgr = tabManager else {
            command.scriptErrorNumber = errAEEventFailed
            command.scriptErrorString = "Tab is no longer available."
            return nil
        }
        mgr.closeWorkspace(ws.id)
        return nil
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let window else { return nil }
        guard let windowClassDescription = window.classDescription as? NSScriptClassDescription else {
            return nil
        }
        guard let windowSpecifier = window.objectSpecifier else { return nil }

        return NSUniqueIDSpecifier(
            containerClassDescription: windowClassDescription,
            containerSpecifier: windowSpecifier,
            key: "tabs",
            uniqueID: idValue
        )
    }
}
