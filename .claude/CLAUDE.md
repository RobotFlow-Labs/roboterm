# ROBOTERM — Project Context

## What
ROS2-native agentic terminal for Apple Silicon. Thin Swift shell over GhosttyKit (Metal GPU terminal).

## Repo
- **GitHub**: https://github.com/RobotFlow-Labs/roboterm
- **Local**: This directory
- **Remote**: `roboterm` (push to this, NOT `origin` which is upstream ghast)

## Build
```bash
./scripts/build.sh --install --run
# or manually:
xcodegen generate
xcodebuild -project roboterm.xcodeproj -scheme roboterm -configuration Debug build
```

## Architecture
- `Sources/` — All Swift code (~2500 lines)
- `Sources/AppleScript/` — Cocoa scripting support (SDEF + wrappers)
- `Resources/Roboterm.sdef` — AppleScript dictionary
- `ghostty/` — Upstream Ghostty submodule (never modify)
- `assets/` — Hero image and HTML template
- `scripts/` — Build scripts
- `~/.config/ghostty/config` — Terminal color theme
- `~/.config/roboterm/hosts.json` — Network hosts for hardware panel
- `~/.config/roboterm/sessions.json` — Session persistence

## Key Files
| File | Purpose |
|------|---------|
| `GhastApp.swift` | App entry point (rename to RobotermApp planned) |
| `AppDelegate.swift` | Window management, main menu, Robotics menu (60+ commands) |
| `ContentView.swift` | Sidebar + tab bar + terminal layout |
| `AgentBar.swift` | Claude/Codex launcher + ROS2 quick buttons |
| `StatusBar.swift` | Bottom bar: CPU/MEM/git/ROS2/clock/hardware |
| `HardwarePanel.swift` | Hardware auto-detection (IOKit + network hosts) |
| `GhosttyManager.swift` | Ghostty lifecycle, action callbacks |
| `TerminalView.swift` | NSView hosting Ghostty surface, right-click menu |
| `TabManager.swift` | Workspace/tab management per window |
| `Workspace.swift` | Tab grouping, ROS2 workspace detection |
| `SessionStore.swift` | Save/restore state to JSON |

## Conventions
- Push to `roboterm` remote, not `origin`
- Use `rg` instead of `grep`
- No rounded corners in UI (Industrial Cyberpunk)
- Colors: #FF3B00 orange, #050505 black, #00FF88 green, #00DDFF cyan
- Font: JetBrains Mono, monospaced everywhere
- All uppercase labels with letter-spacing in sidebar
