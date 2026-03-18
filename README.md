<p align="center">
  <img src="assets/hero.png" alt="ROBOTERM — The Terminal for Robotics Developers" width="100%">
</p>

<p align="center">
  <strong>The first ROS2-native agentic terminal for Apple Silicon.</strong><br>
  Built by <a href="https://robotflowlabs.com">RobotFlow Labs</a> &bull; Pure Swift &bull; <a href="https://github.com/migueldeicaza/SwiftTerm">SwiftTerm</a> Engine
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#build">Build</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#keyboard-shortcuts">Shortcuts</a> &bull;
  <a href="#license">License</a>
</p>

---

## Why ROBOTERM?

Robotics developers on macOS suffer from **fragmented tooling** — jumping between `ros2` CLI, rqt, RViz, Foxglove, Docker, and SSH sessions. ROBOTERM unifies everything into one terminal with:

- **Native SSH connections** — Cursor/Termius-style sidebar, one-click connect, direct PTY process
- **One-click AI agents** (Claude Code, Codex) for agentic development
- **30 `rt` CLI commands** for ROS2 introspection, debugging, and deployment
- **Docker container management** with tree view, play/stop, shell access
- **Hardware auto-detection** (cameras, LiDAR, Jetson, serial devices)
- **ANIMA module management** — per-module Docker, ROS2, and SSH config
- **Pure Swift** — zero C/Zig dependencies, SwiftTerm engine
- **Industrial Cyberpunk design** matching the RobotFlow Labs ecosystem

```
ROBOTERM (Swift, ~6500 lines + 1100 lines shell tools)
    |
    +-- Chrome Layer
    |   +-- Agent launcher bar (Claude Code, Codex + ROS2 buttons)
    |   +-- SSH connections panel (one-click connect, direct PTY)
    |   +-- ANIMA module panel (Docker status, SSH, ROS2 per-module)
    |   +-- Docker container panel (tree view, compose groups)
    |   +-- Hardware panel (IOKit USB hotplug detection)
    |   +-- Status bar (CPU/MEM, git branch, ROS2 domain, SSH info)
    |   +-- 5-tab preferences (General, Appearance, Agents, ANIMA, SSH)
    |   +-- Workspace sidebar (Industrial Cyberpunk design)
    |   +-- AppleScript support (SDEF + Cocoa scripting)
    |   +-- Session persistence (incl. SSH tab restore)
    |
    +-- SwiftTerm (pure Swift terminal engine via SPM)
        +-- Core Text rendering
        +-- VT100/xterm parser
        +-- Built-in shell + SSH process management
        +-- Keyboard, mouse, clipboard handling
```

## Features

### Agent Launcher Bar
One-click launch for AI coding agents directly from the toolbar:
- **Claude Code** — Anthropic's CLI agent
- **Codex** — OpenAI's CLI agent
- Quick buttons: nodes, topics, services, params, gazebo, rviz2, rqt, doctor, docker

### Native SSH Connections
Cursor/Termius-style SSH directly from the sidebar:
- **Direct PTY process** — `/usr/bin/ssh` runs as the terminal process (no shell + sendText hack)
- **Connection profiles** — saved in `~/.config/roboterm/ssh-connections.json`
- **Sidebar panel** — "SSH CONNECTIONS" with one-click connect, cyan accent
- **Tab differentiation** — SSH tabs show network icon, cyan indicator, `[SSH]` title prefix
- **Key file support** — Browse button for `~/.ssh/` identity files
- **Session persistence** — SSH tabs restore on relaunch
- **Smart integration** — SSH tabs skip directory regrouping, status bar shows connection info, agents open in new local tab

### ANIMA Module Management
Per-module configuration for the ANIMA perception stack:
- Docker container name, profile (CPU/GPU), ports, volumes, env vars
- ROS2 node name and watched topics
- SSH remote access with host, user, port, key path
- One-click SSH connect from module context menu

### Docker Container Management
VS Code-style container panel in the sidebar:
- Tree view grouped by Docker Compose project
- Play/stop icons for each container
- Hover actions: Shell, Logs, Stop/Start
- Right-click: full lifecycle management (start, stop, restart, remove)
- Auto-refresh every 10 seconds

### ROS2 Integration (60+ commands)

| Category | Commands |
|----------|----------|
| **Introspect** | nodes, topics, services, actions, params, interfaces, rqt_graph |
| **Diagnostics** | doctor, daemon, multicast, wtf, topic hz/delay |
| **Transforms** | view_frames, tf2_echo, tf2_monitor |
| **Launch & Build** | ros2 launch/run, colcon build/test, --symlink-install |
| **Bag Recording** | record all, record select, play, info |
| **Simulation** | Gazebo, RViz2, rqt, MuJoCo, Isaac Sim |

### CLI Tools (30 commands)
Add to your `~/.bashrc` or `~/.zshrc`:
```bash
[ -n "$ROBOTERM" ] && [ -f "$ROBOTERM_TOOLS" ] && source "$ROBOTERM_TOOLS"
```

```
rt init        — Auto-detect & source ROS2 workspace
rt connect     — Bridge ros2 CLI to Docker container
rt status      — One-line system status
rt nodes       — Live node dashboard
rt topics      — Topic monitor with types
rt services    — Service list with types
rt params      — Parameter browser
rt doctor      — System diagnostics
rt tf          — Transform tree
rt build       — Smart colcon build with auto-source
rt bag         — Bag management (list, info, record, play)
rt hz/echo     — Topic frequency / pretty echo
rt launch      — Enhanced ros2 launch
rt dds         — DDS configuration & diagnostics
rt docker      — Docker helpers (ps, up, down, logs, shell)
rt lifecycle   — Node lifecycle management
rt sensor      — Sensor monitoring (list, watch, hz, bw)
rt ssh         — SSH to configured robots
rt watch       — Watch multiple topics (--all for live)
rt kill        — Kill a ROS2 node
rt graph       — ASCII node connection graph
rt profile     — Environment profiles (list, create, load, save)
rt export      — Export to Foxglove (bag2csv, bag2mcap)
rt disk        — Disk usage for robotics data
rt log         — ROS2 log viewer
rt dupes       — Find duplicate files by hash
rt alias       — Custom command shortcuts
```

### Right-Click Context Menu
- Copy, Paste, Split (Right/Left/Down/Up), Reset Terminal, Select All
- **ROS2 submenu**: nodes, topics, services, doctor, TF tree, topic Hz
- **Launch Agent submenu**: Claude Code, Codex

### Hardware Auto-Detection
IOKit USB hotplug monitor with dedicated CFRunLoop thread:
- Cameras: ZED (2/2i/Mini/X), RealSense, USB cameras
- LiDAR: Velodyne, Ouster, Livox, RPLIDAR, Hokuyo
- Compute: Jetson, Raspberry Pi (via network probe)
- Serial: USB serial devices
- Network hosts from `~/.config/roboterm/hosts.json`

### AppleScript
Full Cocoa scripting support with SDEF dictionary:
```applescript
tell application "ROBOTERM"
    set w to (new window)
    input text "ros2 topic list" to focused terminal of selected tab of w
end tell
```

### Design
Industrial Cyberpunk theme matching [RobotFlow Labs](https://robotflowlabs.com):

| Token | Value | Usage |
|-------|-------|-------|
| `#FF3B00` | Orange | Accent, selected state, local tabs |
| `#050505` | Void Black | Terminal background |
| `#080808` | Near Black | Sidebar background |
| `#00FF88` | Green | Running status, ROS2 |
| `#00DDFF` | Cyan | SSH connections, Docker, cameras |
| `#8B5CFF` | Purple | GPU profiles |
| `#FFB800` | Yellow | Warnings, tools |

- CaskaydiaMono Nerd Font (Oh My Posh support)
- No rounded corners — sharp, industrial
- Monospaced uppercase labels with letter-spacing

## Build

```bash
# Prerequisites
brew install xcodegen

# Build
git clone https://github.com/RobotFlow-Labs/roboterm.git
cd roboterm
xcodegen generate
xcodebuild -project roboterm.xcodeproj -scheme roboterm -configuration Debug build

# Install
./scripts/build.sh --install --run
```

## Architecture

ROBOTERM is a **pure Swift** macOS terminal application using [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) as the terminal engine (Core Text rendering, built-in PTY management). No C bridging headers, no Zig, no xcframeworks — just Swift Package Manager.

| Component | Technology |
|-----------|-----------|
| Terminal engine | SwiftTerm (SPM) |
| UI framework | SwiftUI + AppKit |
| USB detection | IOKit (native) |
| Network probe | Network.framework (NWConnection) |
| Shell tools | Bash (30 `rt` commands) |
| AppleScript | Cocoa scripting (SDEF) |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New Tab |
| `Cmd+W` | Close Tab |
| `Cmd+N` | New Window |
| `Cmd+D` | Split Right |
| `Cmd+Shift+D` | Split Down |
| `Cmd+=` | Zoom In |
| `Cmd+-` | Zoom Out |
| `Cmd+0` | Reset Zoom |
| `Ctrl+Cmd+F` | Toggle Fullscreen |
| `Cmd+Shift+L` | ros2 launch |
| `Cmd+Shift+B` | colcon build |

## Roadmap

### Shipped (v0.5.0)
- [x] Pure Swift terminal (SwiftTerm engine)
- [x] Agent launcher bar (Claude + Codex)
- [x] Docker container management (tree view)
- [x] 60+ ROS2 menu commands
- [x] 30 `rt` CLI commands
- [x] Docker-ROS2 bridge (`rt connect`)
- [x] IOKit USB hotplug detection
- [x] AppleScript support
- [x] Session persistence (incl. SSH tabs)
- [x] Hardware auto-detection
- [x] Custom app icon
- [x] Industrial Cyberpunk design
- [x] ANIMA module management (per-module Docker/SSH/ROS2)
- [x] Native SSH connections (direct PTY, sidebar panel, key files)
- [x] 5-tab preferences (General, Appearance, Agents, ANIMA, SSH)
- [x] Split panes (horizontal + vertical)
- [x] Tab drag-and-drop reordering

### Next (v0.6.0)
- [ ] RosSwift native integration (pub/sub without CLI)
- [ ] Inline camera/LiDAR preview
- [ ] Bag timeline viewer
- [ ] Recording indicator in status bar
- [ ] ROS2 node graph TUI visualization

## License

Apache 2.0

## Credits

- Terminal engine: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza
- Built by [RobotFlow Labs](https://robotflowlabs.com) / [AIFLOW LABS](https://aiflowlabs.io)
