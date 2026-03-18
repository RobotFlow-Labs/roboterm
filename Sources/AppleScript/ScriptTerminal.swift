import AppKit

/// AppleScript-facing wrapper around a live ROBOTERM terminal surface (Tab + TerminalView).
///
/// Mapping from `Roboterm.sdef`:
/// - `class terminal` → this class (`@objc(RobotermScriptTerminal)`).
/// - `property id` → `stableID`
/// - `property title` → `title`
/// - `property working directory` → `workingDirectory`
@MainActor
@objc(RobotermScriptTerminal)
final class ScriptTerminal: NSObject {
    weak var tab: Tab?

    init(tab: Tab) {
        self.tab = tab
    }

    @objc(id)
    var stableID: String {
        tab?.id.uuidString ?? ""
    }

    @objc(title)
    var title: String {
        tab?.title ?? ""
    }

    @objc(workingDirectory)
    var workingDirectory: String {
        tab?.currentDirectory ?? tab?.initialWorkingDirectory ?? ""
    }

    /// Send text to the terminal (used by AppleScript `input text`).
    func sendText(_ text: String) {
        tab?.terminalView?.sendText(text)
    }

    /// Handler for `split <terminal> direction <dir>`.
    @objc(handleSplitCommand:)
    func handleSplit(_ command: NSScriptCommand) -> Any? {
        guard let tab else {
            command.scriptErrorNumber = errAEEventFailed
            command.scriptErrorString = "Terminal is no longer available."
            return nil
        }

        guard let directionCode = command.evaluatedArguments?["direction"] as? UInt32 else {
            command.scriptErrorNumber = errAEParamMissed
            command.scriptErrorString = "Missing split direction."
            return nil
        }

        let direction: SplitNode.SplitDirection
        switch directionCode {
        case fourCC("RSrt"): direction = .horizontal
        case fourCC("RSdn"): direction = .vertical
        default:
            command.scriptErrorNumber = errAEParamMissed
            command.scriptErrorString = "Unknown split direction."
            return nil
        }

        // Find workspace containing this tab
        guard let appDelegate = AppDelegate.shared else { return nil }
        for mgr in appDelegate.tabManagers {
            for ws in mgr.workspaces where ws.tabs.contains(where: { $0.id == tab.id }) {
                let newTab = ws.createSplitTab(nextTo: tab.id, direction: direction)
                return ScriptTerminal(tab: newTab)
            }
        }

        command.scriptErrorNumber = errAEEventFailed
        command.scriptErrorString = "Tab not found in any workspace."
        return nil
    }

    /// Handler for `focus <terminal>`.
    @objc(handleFocusCommand:)
    func handleFocus(_ command: NSScriptCommand) -> Any? {
        tab?.focus()
        return nil
    }

    /// Handler for `close <terminal>`.
    @objc(handleCloseCommand:)
    func handleClose(_ command: NSScriptCommand) -> Any? {
        guard let tab else {
            command.scriptErrorNumber = errAEEventFailed
            command.scriptErrorString = "Terminal is no longer available."
            return nil
        }

        guard let appDelegate = AppDelegate.shared else { return nil }
        for mgr in appDelegate.tabManagers {
            mgr.closeTab(tab.id)
        }
        return nil
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appClassDescription = NSApplication.shared.classDescription as? NSScriptClassDescription else {
            return nil
        }
        return NSUniqueIDSpecifier(
            containerClassDescription: appClassDescription,
            containerSpecifier: nil,
            key: "terminals",
            uniqueID: stableID
        )
    }
}

/// Convert a 4-character string to its FourCharCode UInt32.
func fourCC(_ s: String) -> UInt32 {
    var result: UInt32 = 0
    for (i, c) in s.utf8.enumerated() where i < 4 {
        result = (result << 8) | UInt32(c)
    }
    return result
}
