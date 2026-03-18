# ROBOTERM

**The first ROS2-native agentic terminal for Apple Silicon.**

Built by [RobotFlow Labs](https://robotflowlabs.com). Thin shell over [GhosttyKit](https://github.com/ghostty-org/ghostty) (Metal GPU terminal) with robotics-first features.

```
ROBOTERM (Swift, ~2500 lines)
    |
    +-- Chrome Layer (our code)
    |   +-- Agent launcher bar (Claude Code, Codex)
    |   +-- Robotics menu (60+ ROS2 commands)
    |   +-- Status bar (CPU/MEM, git, ROS2 domain, clock)
    |   +-- Workspace sidebar (Industrial Cyberpunk design)
    |   +-- AppleScript support (full SDEF dictionary)
    |   +-- Session persistence
    |
    +-- GhosttyKit.xcframework (upstream, never modified)
        +-- Metal GPU-accelerated terminal renderer
        +-- VT100/xterm parser
        +-- 43 action callbacks
```

## Features

### Agent Launcher Bar
One-click launch for AI coding agents:
- **Claude Code** — Anthropic's CLI agent
- **Codex** — OpenAI's CLI agent

### ROS2 Integration (60+ commands)
- **Introspect**: nodes, topics, services, actions, params, interfaces, rqt_graph
- **Diagnostics**: doctor, daemon, multicast, wtf, topic hz/delay
- **Transforms**: view_frames, tf2_echo, tf2_monitor
- **Launch & Build**: ros2 launch/run, colcon build/test
- **Bag Recording**: record, play, info
- **Simulation**: Gazebo, RViz2, rqt, MuJoCo, Isaac Sim

### Right-Click Context Menu
- Copy, Paste, Split (4 directions), Reset Terminal
- ROS2 submenu (nodes, topics, services, doctor, TF, Hz)
- Launch Agent submenu (Claude, Codex)

### Status Bar
Live system info with zero overhead:
- CPU/MEM via mach APIs (no subprocess)
- Git branch from filesystem read
- ROS2 distro & domain ID from env vars
- Clock

### Docker Integration
- `docker compose ps/up/down/logs`
- `docker ps`, `docker images`

### Hardware
- Camera, LiDAR, IMU, Gamepad status via `ros2 topic echo`
- USB device listing (`system_profiler`)
- Serial port discovery
- SSH to robot

### AppleScript
Full Cocoa scripting support:
```applescript
tell application "ROBOTERM"
    set w to (new window)
    input text "ros2 topic list" to focused terminal of selected tab of w
end tell
```

### Design
Industrial Cyberpunk theme matching [RobotFlow Labs](https://robotflowlabs.com):
- `#FF3B00` orange accent
- `#050505` void black background
- `#00FF88` green for status indicators
- JetBrains Mono font
- No rounded corners

## Build

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project roboterm.xcodeproj -scheme roboterm -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/roboterm-*/Build/Products/Debug/ROBOTERM.app
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+T | New Tab |
| Cmd+W | Close Tab |
| Cmd+N | New Window |
| Cmd+D | Split Right |
| Cmd+Shift+D | Split Down |
| Cmd+Shift+L | ros2 launch |
| Cmd+Shift+B | colcon build |

## License

Apache 2.0

## Credits

- Terminal engine: [Ghostty](https://github.com/ghostty-org/ghostty) by Mitchell Hashimoto
- Built by [RobotFlow Labs](https://robotflowlabs.com) / [AIFLOW LABS](https://aiflowlabs.io)
