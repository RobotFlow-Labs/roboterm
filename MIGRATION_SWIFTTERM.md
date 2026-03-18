# ROBOTERM — GhosttyKit to SwiftTerm Migration Plan

**Date:** 2026-03-15
**Target:** macOS 13+ Apple Silicon
**SwiftTerm:** github.com/migueldeicaza/SwiftTerm (pure Swift, no native dependencies)

---

## 1. Executive Summary

GhosttyKit is a Zig-compiled xcframework that exposes a C API. It owns its own rendering
pipeline (Metal), config loading, process management, and key binding engine. SwiftTerm is
a pure-Swift VT100/VT220/xterm terminal emulator that provides the parsing and screen model
but delegates process management and rendering to the host app via a delegate protocol.

The migration is a complete swap of the terminal engine layer. The tab/workspace/split
architecture, all SwiftUI views, the menu system, and session persistence are entirely
unaffected. The only files that are fundamentally rewritten are:

- `TerminalView.swift` — the NSView that wraps the terminal engine
- `GhosttyManager.swift` — deleted (no equivalent singleton needed)
- `GhastApp.swift` — simplified (remove Ghostty env setup)
- `ghast-Bridging-Header.h` / `roboterm-Bridging-Header.h` — deleted
- `ghostty.h` — deleted (not needed)
- `project.yml` — replace xcframework dependency with SPM

The rest of the codebase (`ContentView.swift`, `Tab.swift`, `TabManager.swift`,
`Workspace.swift`, `SplitNode.swift`, `SplitContainerView.swift`, `StatusBar.swift`,
`AgentBar.swift`, `HardwarePanel.swift`, `SessionStore.swift`, `AppDelegate.swift`) changes
only at call sites where ghostty C functions were called, which is a small, contained set.

---

## 2. SwiftTerm API Overview

SwiftTerm ships two high-level view types for macOS:

### `LocalProcessTerminalView` (AppKit, inherits `TerminalView`)

This is the primary integration target. It is a ready-made `NSView` subclass that:

- Spawns a shell using `posix_spawn` via `LocalProcess`
- Parses all VT escape sequences internally
- Renders using Core Text + `CALayer` (no Metal required)
- Handles keyboard, mouse, scroll wheel, and clipboard internally
- Fires delegate callbacks for title changes, bell, directory changes (OSC 7),
  clipboard requests, and process exit

Key initializer:

```swift
let termView = LocalProcessTerminalView(frame: rect)
termView.processDelegate = self   // LocalProcessTerminalViewDelegate
termView.terminalDelegate = self  // optional TerminalViewDelegate for title/bell
```

Starting the shell:

```swift
// Launch default shell in a specific directory
termView.startProcess(executable: "/bin/zsh",
                      arguments: [],
                      environment: nil,   // inherits parent env
                      execName: nil,
                      startDirectory: workingDirectory)
```

Sending text programmatically (equivalent of `ghostty_surface_text`):

```swift
termView.send(txt: "ros2 node list\n")
// or the Data overload:
termView.send(data: Data("clear\n".utf8))
```

### `TerminalView` (AppKit base class)

`LocalProcessTerminalView` inherits from this. Its delegate:

```swift
protocol TerminalViewDelegate: AnyObject {
    // Title changed (shell set via OSC 0/2)
    func setTerminalTitle(source: TerminalView, title: String)
    // Terminal icon name changed (OSC 1)
    func setTerminalIconTitle(source: TerminalView, title: String)
    // Terminal size changed (columns/rows)
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int)
    // Clipboard write request (OSC 52)
    func clipboardCopy(source: TerminalView, content: Data)
    // Terminal rang the bell
    func bell(source: TerminalView)
    // Host name/user set via OSC 6 / OSC 7
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String)
    // Mouse cursor tracking state changed
    func requestOpenLink(source: TerminalView, link: String, params: [String:String])
    // Scroll position feedback
    func scrolled(source: TerminalView, position: Double)
    // Color change notification
    func colorChanged(source: TerminalView, idx: Int?, color: Color?)
    // Iterm2/Kitty image protocol (can be no-op)
    func processTerminated(source: TerminalView, exitCode: Int32?)
}
```

### `LocalProcessTerminalViewDelegate`

Extends `TerminalViewDelegate` with one additional callback:

```swift
protocol LocalProcessTerminalViewDelegate: TerminalViewDelegate {
    // Shell process exited
    func processTerminated(source: LocalProcessTerminalView, exitCode: Int32?)
}
```

### Color / Theme API

```swift
// Set terminal background
termView.nativeBackgroundColor = NSColor.black

// Set full 16-color palette
termView.installColors(AnsiColors.dark)   // uses SwiftTerm's AnsiColors presets

// Or set individual colors:
termView.terminal.foregroundColor = ...
```

### Scrollback API

```swift
// Scroll position (0.0 = top, 1.0 = bottom)
termView.scrollPosition(value: 1.0)

// Page up/down
termView.pageUp()
termView.pageDown()
```

### `LocalProcess`

`LocalProcessTerminalView` owns a `LocalProcess` internally. You do not touch it directly
in most cases. The view manages PTY creation, `posix_spawn`, and the read/write loop
on a background thread. The only direct `LocalProcess` interaction needed is to send
text (via the view API above) and to observe exit.

---

## 3. Complete Ghostty C API to SwiftTerm Mapping

### Lifecycle

| Ghostty C function | SwiftTerm equivalent |
|---|---|
| `ghostty_init(argc, argv)` | Nothing — no global init |
| `ghostty_config_new()` | Nothing — SwiftTerm reads no config files |
| `ghostty_config_load_default_files(cfg)` | Nothing |
| `ghostty_config_load_recursive_files(cfg)` | Nothing |
| `ghostty_config_load_file(cfg, path)` | Nothing |
| `ghostty_config_finalize(cfg)` | Nothing |
| `ghostty_config_free(cfg)` | Nothing |
| `ghostty_config_get(cfg, &val, key, len)` | Read `UserDefaults` or a custom `Settings` model directly |
| `ghostty_app_new(&rt, cfg)` | Nothing — no app-level handle |
| `ghostty_app_tick(app)` | Nothing — SwiftTerm's runloop is internal |
| `ghostty_app_set_focus(app, focused)` | Nothing — SwiftTerm uses standard `becomeFirstResponder` |
| `ghostty_app_free(app)` | Nothing |
| `ghostty_surface_new(app, &config)` | `LocalProcessTerminalView(frame:)` + `startProcess(...)` |
| `ghostty_surface_free(surface)` | `termView.removeFromSuperview()` / ARC dealloc |

### Rendering / Size

| Ghostty C function | SwiftTerm equivalent |
|---|---|
| `ghostty_surface_set_size(surface, w, h)` | Automatic — SwiftTerm recalculates on `setFrameSize` |
| `ghostty_surface_set_content_scale(surface, sx, sy)` | Automatic — SwiftTerm observes `backingScaleFactor` |
| `ghostty_surface_set_display_id(surface, id)` | Not needed |
| `ghostty_surface_refresh(surface)` | `termView.needsDisplay = true` (rarely needed, SwiftTerm self-invalidates) |

### Focus

| Ghostty C function | SwiftTerm equivalent |
|---|---|
| `ghostty_surface_set_focus(surface, focused)` | `window?.makeFirstResponder(termView)` / standard NSView focus |

### Keyboard input

| Ghostty C function | SwiftTerm equivalent |
|---|---|
| `ghostty_surface_key(surface, keyEvent)` | Handled internally by `LocalProcessTerminalView.keyDown` |
| `ghostty_surface_key_is_binding(surface, keyEvent, &flags)` | Not needed — no binding engine; implement app-level shortcuts in AppDelegate menu |
| `ghostty_surface_binding_action(surface, action, len)` | Not needed — translate to direct Swift calls |
| `ghostty_surface_preedit(surface, text, len)` | Handled internally (SwiftTerm implements `NSTextInputClient`) |

### Mouse input

| Ghostty C function | SwiftTerm equivalent |
|---|---|
| `ghostty_surface_mouse_pos(surface, x, y, mods)` | Handled internally by `LocalProcessTerminalView` |
| `ghostty_surface_mouse_button(surface, state, button, mods)` | Handled internally |
| `ghostty_surface_mouse_scroll(surface, dx, dy, mods)` | Handled internally |

### Text / Clipboard

| Ghostty C function | SwiftTerm equivalent |
|---|---|
| `ghostty_surface_text(surface, ptr, len)` | `termView.send(txt: string)` |
| `ghostty_surface_complete_clipboard_request(surface, text, state, conform)` | Not needed — SwiftTerm clipboard is delegate-driven via `clipboardCopy` callback |

### IME

| Ghostty C function | SwiftTerm equivalent |
|---|---|
| `ghostty_surface_ime_point(surface, &x, &y, &w, &h)` | SwiftTerm implements `firstRect(forCharacterRange:)` internally |

### Actions (previously driven by `ghostty_runtime_config_s` callbacks)

| Ghostty action | SwiftTerm equivalent |
|---|---|
| `GHOSTTY_ACTION_NEW_WINDOW` | Menu item / keyboard shortcut → `AppDelegate.createNewWindow()` |
| `GHOSTTY_ACTION_NEW_TAB` | Menu item / keyboard shortcut → `tabManager.createTab()` |
| `GHOSTTY_ACTION_CLOSE_TAB` | Menu item / keyboard shortcut → `tabManager.closeTab(id)` |
| `GHOSTTY_ACTION_CLOSE_WINDOW` | Menu item → `window.close()` |
| `GHOSTTY_ACTION_SET_TITLE` | `TerminalViewDelegate.setTerminalTitle(source:title:)` |
| `GHOSTTY_ACTION_PWD` | `TerminalViewDelegate.hostCurrentDirectoryUpdate(source:directory:)` (OSC 7) |
| `GHOSTTY_ACTION_GOTO_TAB` | Menu items already wired in `AppDelegate.buildMainMenu()` |
| `GHOSTTY_ACTION_NEW_SPLIT` | Menu item → `ws.createSplitTab(...)` |
| `GHOSTTY_ACTION_GOTO_SPLIT` | Menu items in `AppDelegate` already implemented |
| `GHOSTTY_ACTION_TOGGLE_FULLSCREEN` | `window.toggleFullScreen(nil)` |
| `GHOSTTY_ACTION_QUIT` | `NSApp.terminate(nil)` |
| `GHOSTTY_ACTION_OPEN_URL` | `NSWorkspace.shared.open(url)` |
| `GHOSTTY_ACTION_DESKTOP_NOTIFICATION` | `UNUserNotificationCenter` (already written in GhosttyManager) |
| `GHOSTTY_ACTION_RING_BELL` | `TerminalViewDelegate.bell(source:)` → `NSSound.beep()` |
| `GHOSTTY_ACTION_RELOAD_CONFIG` | Custom `SettingsManager` — reload and re-apply to all views |
| `GHOSTTY_ACTION_RENDER` | Not needed |
| `GHOSTTY_ACTION_RESIZE_SPLIT` | Drag divider (already handled by `SplitContainerView.DividerView`) |
| `GHOSTTY_ACTION_EQUALIZE_SPLITS` | Set all `SplitNode` ratios to 0.5 |
| `GHOSTTY_ACTION_TOGGLE_SPLIT_ZOOM` | Hide split, show single tab fullscreen |
| `copy:clipboard` action string | `NSPasteboard.general.setString(termView.getSelectedText(), forType: .string)` |
| `select_all` action string | `termView.selectAll(nil)` |

---

## 4. File-by-File Migration Plan

### Files DELETED

| File | Reason |
|---|---|
| `GhosttyManager.swift` | Entire file replaced by `TerminalSettings.swift` (a simple value model) |
| `ghast-Bridging-Header.h` | No C API bridge needed |
| `roboterm-Bridging-Header.h` | No C API bridge needed |
| `ghostty.h` | C header for libghostty, not needed |
| `ghostty/` directory | The xcframework tree |

### Files REWRITTEN

#### `TerminalView.swift` — Full rewrite, ~489 lines → ~200 lines

`TerminalView` becomes a thin subclass of `LocalProcessTerminalView` that:

1. Stores `tabId: UUID` and `workingDirectory: String?` (same as today)
2. On `viewDidMoveToWindow`, calls `startProcess` with the correct shell and directory
3. Implements `LocalProcessTerminalViewDelegate` to:
   - Forward title changes to `Tab.title`
   - Forward OSC 7 directory changes to `TabManager.handleDirectoryChange`
   - Close the tab on `processTerminated`
4. Exposes `sendText(_ text: String)` (wraps `send(txt:)`)
5. Overrides `rightMouseDown` to show the same context menu (no change to menu structure)
6. Keeps the `terminalViewDidFocus` notification on `mouseDown`

The following are completely eliminated from `TerminalView.swift`:

- `SurfaceCallbackContext` class
- `createSurface()` / `updateSurfaceSize()` (SwiftTerm does this)
- All `ghostty_surface_*` calls (dozens of call sites)
- `keyDown`, `keyUp`, `flagsChanged`, `performKeyEquivalent` overrides (SwiftTerm handles all of these)
- The entire `NSTextInputClient` implementation (SwiftTerm has its own)
- `modsFromEvent`, `unshiftedCodepoint` helpers
- The `NSScreen.displayID` extension (no longer needed)

The split-related `updateSurfaceSize()` calls in `SplitContainerView.adoptTerminalView`
are replaced by `termView.needsDisplay = true` (layout triggers a SwiftTerm resize
automatically because it overrides `setFrameSize`).

**New pseudo-signature:**

```swift
class TerminalView: LocalProcessTerminalView, LocalProcessTerminalViewDelegate {
    let surfaceId: UUID         // kept for compatibility with SplitContainerView lookups
    let tabId: UUID
    var workingDirectory: String?

    init(frame: NSRect, tabId: UUID, workingDirectory: String?)
    func sendText(_ text: String)       // replaces ghostty_surface_text
    // ... right-click menu, same structure as today
}
```

#### `GhastApp.swift` — Small rewrite

Remove the entire `configureGhosttyEnvironment()` method. Keep:
- `TERM=xterm-256color` (change from `xterm-ghostty`)
- `TERM_PROGRAM=roboterm`
- `ROBOTERM=1`
- `ROBOTERM_TOOLS` path

Remove:
- `GHOSTTY_RESOURCES_DIR` lookup
- The `_ = GhosttyManager.shared` initialization in `AppDelegate`

#### `AppDelegate.swift` — Minimal changes

Only `runCommand` and `runCommandInNewTab` need updating:

```swift
// Before
cmd.withCString { ptr in ghostty_surface_text(surface, ptr, UInt(cmd.utf8.count)) }

// After
tab.terminalView?.sendText(cmd)
```

The `ContentView.swift` reference to `GhosttyManager.shared.backgroundColor` needs
to be replaced by a local `TerminalSettings.shared.backgroundColor` (an `NSColor`
stored in a simple singleton or UserDefaults).

`ContentView.swift` line 286 (`TabBar`):
```swift
// Before
private var bgColor: Color { Color(nsColor: GhosttyManager.shared.backgroundColor) }

// After
private var bgColor: Color { Color(nsColor: TerminalSettings.shared.backgroundColor) }
```

#### `SplitContainerView.swift` — Minor changes

Remove the two remaining ghostty calls:

```swift
// Before
ghostty_surface_refresh(surface)

// After
terminalView.needsDisplay = true
```

Remove the `if let surface = terminalView.surface` guard (SwiftTerm is always ready).
Remove `terminalView.createSurface()` call in `adoptTerminalView`.
Remove `terminalView.updateSurfaceSize()` call (automatic with SwiftTerm).

#### `ContentView.swift` — Two lines changed

Only the `GhosttyManager.shared.backgroundColor` references in `TabBar` and
`AppDelegate.createWindowForTabManager`. Replace with `TerminalSettings.shared.backgroundColor`.

### Files ADDED

#### `TerminalSettings.swift` (new, ~80 lines)

Replaces `GhosttyManager`'s config-reading responsibility. A simple `@MainActor` singleton
that owns the terminal appearance settings with sensible defaults:

```swift
@MainActor
final class TerminalSettings {
    static let shared = TerminalSettings()

    var backgroundColor: NSColor = .black
    var foregroundColor: NSColor = .white
    var fontName: String = "Menlo"
    var fontSize: CGFloat = 13
    var shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

    // Load from ~/.config/roboterm/config.json or UserDefaults
    func load() { ... }
}
```

### Files UNCHANGED

| File | Notes |
|---|---|
| `Tab.swift` | No ghostty references; `terminalView` type stays `TerminalView` |
| `TabManager.swift` | Pure Swift, no ghostty references |
| `Workspace.swift` | Pure Swift, no ghostty references |
| `SplitNode.swift` | Pure Swift, no ghostty references |
| `SessionStore.swift` | Pure Swift, no ghostty references |
| `AgentBar.swift` | Pure SwiftUI |
| `HardwarePanel.swift` | Pure SwiftUI |
| `StatusBar.swift` | Pure SwiftUI |

---

## 5. project.yml Changes

### Remove
```yaml
dependencies:
  - framework: ghostty/macos/GhosttyKit.xcframework
    embed: false
```

### Remove from `OTHER_LDFLAGS`
```
-lc++, Metal, QuartzCore, IOSurface (possibly keep if used elsewhere), Carbon
```

### Add SPM dependency
```yaml
packages:
  SwiftTerm:
    url: https://github.com/migueldeicaza/SwiftTerm.git
    from: 1.2.5

targets:
  roboterm:
    dependencies:
      - package: SwiftTerm
        product: SwiftTerm
```

### Update bridging header setting
Remove `SWIFT_OBJC_BRIDGING_HEADER` from settings base entirely (no C interop needed).

---

## 6. Shell Process Architecture Comparison

### Ghostty (current)
- Ghostty spawns the shell process internally as part of `ghostty_surface_new`
- Working directory is passed via `config.working_directory`
- The Zig runtime manages the PTY and the read/write loop
- ROBOTERM has no direct handle to the process PID or file descriptor

### SwiftTerm (new)
- `LocalProcessTerminalView.startProcess(executable:arguments:environment:execName:startDirectory:)`
  spawns the shell directly using `posix_spawn` + openpty
- ROBOTERM owns the process start call, so it can set arbitrary env vars and args
- `processTerminated(source:exitCode:)` delegate method fires on shell exit
- The shell PID is accessible via `terminalView.shellPid` (a `pid_t`) — useful for future
  features like attaching to existing processes or sending signals

---

## 7. Features Lost in Migration

### Definite losses

| Feature | Notes |
|---|---|
| Ghostty config file compatibility | `~/.config/ghostty/config` parsing is dropped. Font, color, and keybinding settings must be reimplemented in `TerminalSettings` using a simple JSON/plist or UserDefaults. |
| Ghostty key binding engine | `ghostty_surface_key_is_binding` / `GHOSTTY_ACTION_*` routing is gone. All keyboard shortcuts must be declared as standard `NSMenuItem` equivalents in `AppDelegate.buildMainMenu()`. This is already largely the case — the main menu already has all the shortcuts. |
| Kitty keyboard protocol | Ghostty uses the Kitty keyboard protocol for extended key reporting. SwiftTerm emits standard VT sequences. Most terminal apps are compatible but some niche ncurses UIs (e.g., Helix editor) may see minor differences in modifier key reporting. |
| Metal-accelerated GPU rendering | Ghostty renders to a Metal surface. SwiftTerm uses Core Text on `CALayer`. For a robotics terminal workload (mostly text), Core Text performance is entirely adequate. |
| Background opacity / vibrancy | `ghostty_config_get` for `background-opacity` is gone. Window transparency must be wired manually using `NSWindow.alphaValue` and `NSVisualEffectView`. |
| IME cursor position hint | Ghostty's `ghostty_surface_ime_point` told the OS exactly where to position the IME input panel. SwiftTerm provides a built-in `firstRect(forCharacterRange:)` implementation that approximates the cursor position, which is correct for the common case. |
| OSC 52 selection clipboard | SwiftTerm does not support OSC 52 selection clipboard by default. The standard clipboard copy/paste via `clipboardCopy` delegate works correctly. This affects tmux clipboard integration in niche configs. |
| `TERM=xterm-ghostty` | Change to `TERM=xterm-256color`. Any shell prompt or tool that was testing for `xterm-ghostty` must be updated. The `TERM_PROGRAM=roboterm` identifier is preserved. |

### Not lost (common misconceptions)

| Feature | Notes |
|---|---|
| Mouse reporting | SwiftTerm has full X10/SGR/URXVT mouse reporting. tmux mouse mode works. |
| 256-color / truecolor | Fully supported. |
| Alternate screen (vi, less) | Fully supported. |
| Bracketed paste | Fully supported. |
| OSC 7 (directory tracking) | Supported via `hostCurrentDirectoryUpdate`. The workspace auto-grouping feature is preserved without changes. |
| OSC 0/2 (title changes) | Supported via `setTerminalTitle`. Tab titles update as before. |
| Tab title from shell | Preserved — `setTerminalTitle` delegate → `Tab.title`. |
| Session restore | Preserved — `SessionStore` is unchanged. |
| Split panes | Preserved — `SplitNode` / `SplitContainerView` are unchanged. |
| ROS2 menu commands | Preserved — `sendText` replaces `ghostty_surface_text`. |
| Working directory inheritance | Preserved — `startProcess(startDirectory:)` replaces `config.working_directory`. |
| Scrollback | SwiftTerm has configurable scrollback (default 500 lines). Configure via `termView.terminal.scrollbackSize`. |

---

## 8. Effort Estimate

| File | Action | Effort |
|---|---|---|
| `project.yml` | Remove xcframework, add SPM | 15 min |
| `GhosttyManager.swift` | Delete | 0 min |
| `ghast-Bridging-Header.h` | Delete | 0 min |
| `roboterm-Bridging-Header.h` | Delete | 0 min |
| `ghostty.h` | Delete | 0 min |
| `ghostty/` directory | Delete from repo | 5 min |
| `TerminalSettings.swift` | Write from scratch | 45 min |
| `TerminalView.swift` | Full rewrite | 2-3 hours |
| `GhastApp.swift` | Remove ghostty env config | 10 min |
| `AppDelegate.swift` | Replace `ghostty_surface_text` with `sendText` at 4 call sites | 15 min |
| `SplitContainerView.swift` | Remove 3 ghostty calls | 15 min |
| `ContentView.swift` | Replace 2 GhosttyManager references | 10 min |
| Integration testing | Tab lifecycle, splits, keyboard, clipboard, ROS2 menus | 3-4 hours |
| **Total** | | **~7-9 hours** |

The dominant effort is `TerminalView.swift`. The rewrite is substantially simpler than
the original because SwiftTerm internalizes keyboard, mouse, IME, scroll, and process
management. The new file will be roughly 40% the size of the current one.

---

## 9. Migration Execution Order

Recommended sequence to minimize broken intermediate states:

1. Add SwiftTerm to `project.yml` and confirm it builds (do not yet remove ghostty).
2. Write `TerminalSettings.swift` as a parallel to `GhosttyManager`.
3. Rewrite `TerminalView.swift` using SwiftTerm, keeping the same class name and public
   interface (`sendText`, `tabId`, `surfaceId`, `workingDirectory`) so callers compile.
4. Update `SplitContainerView.swift` to remove ghostty calls (the `surface` property
   is gone — remove `terminalView.surface` guards).
5. Update `AppDelegate.swift` `runCommand` / `runCommandInNewTab` to use `sendText`.
6. Update `ContentView.swift` and `AppDelegate.createWindowForTabManager` to use
   `TerminalSettings.shared.backgroundColor`.
7. Update `GhastApp.swift` to remove ghostty env setup.
8. Remove bridging headers and update `project.yml` to remove the header search path
   and xcframework.
9. Delete `GhosttyManager.swift`, bridging headers, `ghostty.h`, and the `ghostty/`
   directory.
10. Full regression test: open tab, split, type, paste, ROS2 menu, close.

---

## 10. Key Implementation Notes for `TerminalView.swift`

### Shell startup

```swift
override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window != nil, !processStarted else { return }
    processStarted = true
    let shell = TerminalSettings.shared.shell
    startProcess(
        executable: shell,
        arguments: [],
        environment: buildEnvironment(),
        execName: (shell as NSString).lastPathComponent,
        startDirectory: workingDirectory
    )
    window?.makeFirstResponder(self)
}

private func buildEnvironment() -> [String] {
    var env = ProcessInfo.processInfo.environment
    env["TERM"] = "xterm-256color"
    env["TERM_PROGRAM"] = "roboterm"
    env["ROBOTERM"] = "1"
    if let tools = Bundle.main.path(forResource: "roboterm-tools", ofType: "sh") {
        env["ROBOTERM_TOOLS"] = tools
    }
    // Remove NO_COLOR if set
    env.removeValue(forKey: "NO_COLOR")
    return env.map { "\($0.key)=\($0.value)" }
}
```

### Title and directory tracking

```swift
func setTerminalTitle(source: TerminalView, title: String) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        // Find the Tab owning this view and update its title
        NotificationCenter.default.post(
            name: .terminalTitleChanged,
            object: self,
            userInfo: ["title": title]
        )
    }
}

func hostCurrentDirectoryUpdate(source: TerminalView, directory: String) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        NotificationCenter.default.post(
            name: .terminalDirectoryChanged,
            object: self,
            userInfo: ["directory": directory]
        )
    }
}
```

`Tab.swift` and `TabManager.swift` observe these notifications instead of relying on
the ghostty action callback chain through `GhosttyManager`.

### Copy/paste in the context menu

```swift
@objc private func copySelection(_ sender: Any?) {
    // SwiftTerm copies via standard NSText copy: action
    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
}

@objc private func pasteClipboard(_ sender: Any?) {
    if let content = NSPasteboard.general.string(forType: .string) {
        send(txt: content)
    }
}

@objc private func selectAllText(_ sender: Any?) {
    selectAll(nil)
}

@objc private func clearTerminal(_ sender: Any?) {
    send(txt: "clear\n")
}
```

### Process exit → close tab

```swift
func processTerminated(source: LocalProcessTerminalView, exitCode: Int32?) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        NotificationCenter.default.post(
            name: .terminalProcessExited,
            object: self,
            userInfo: ["tabId": tabId]
        )
    }
}
```

`TabManager` observes `terminalProcessExited` and calls `closeTab(tabId)`. This
replaces the `ghostty_runtime_config_s.close_surface_cb` callback.

---

## 11. Configuration Compatibility Notes

The Ghostty config file (`~/.config/ghostty/config`) is a custom format with hundreds
of keys. After migration:

- Font family → `TerminalSettings.fontName` (default: Menlo)
- Font size → `TerminalSettings.fontSize` (default: 13)
- Background color → `TerminalSettings.backgroundColor`
- Foreground color → `TerminalSettings.foregroundColor`
- Cursor style → `termView.caretColor` / `termView.terminal.cursorStyle`
- Key bindings → Hard-coded in `AppDelegate.buildMainMenu()`

A migration prompt on first launch ("Your Ghostty config was not imported. Configure
font and color in ROBOTERM preferences.") would smooth the user experience.

---

## 12. SwiftTerm Package Version

Use tag `1.2.5` or later (latest stable as of 2026-03-15). The package requires
Swift 5.7+ and macOS 11+, which is compatible with the project's macOS 13+ target.

SPM URL: `https://github.com/migueldeicaza/SwiftTerm.git`

The `SwiftTerm` product (not `SwiftTermApp`) is the correct target — `SwiftTermApp`
is a sample app, not a library product.
