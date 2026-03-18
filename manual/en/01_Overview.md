# fWarrange Product Overview

## What is fWarrange?

fWarrange is a **window layout restoration tool** that remembers your macOS working environment and restores all window positions and sizes with a single action.

When working with multiple monitors or complex development/design setups, you no longer need to manually rearrange scattered windows. Instantly restore app window arrangements for specific purposes (development, meetings, design, etc.).

## Key Features

| Feature | Description |
|---------|-------------|
| Layout Capture | Saves all active window positions/sizes as YAML using CoreGraphics |
| Smart Restore | Score-based matching algorithm restores windows even when IDs change |
| Multiple Layouts | Manage multiple profiles for different purposes |
| Multi-Monitor | Full support for secondary monitors |
| REST API | HTTP-based remote control (automation, Apple Shortcuts integration) |
| Claude Code Skill | Manage layouts via natural language in AI agents |
| MCP Server | Direct tool invocation from AI tools (Claude Desktop, etc.) |

## Architecture

fWarrange consists of two components:

```
+----------------------------------+
|  SwiftUI GUI (Menu Bar App)      |
|  - 5-tab settings                |
|  - Built-in REST API server      |
+----------------------------------+
          |  calls
+----------------------------------+
|  Swift Core Scripts              |
|  lib/wArrange_core/              |
|  - saveWindowsInfo.swift (capture)|
|  - setWindows.swift (restore)     |
+----------------------------------+
          |  uses
+----------------------------------+
|  macOS System APIs               |
|  - CoreGraphics (read windows)    |
|  - Accessibility API (control)    |
+----------------------------------+
```

## Data Flow

```
[CoreGraphics] CGWindowListCopyWindowInfo()
      | Collect window info (id, pos, size, layer)
      v
[saveWindowsInfo.swift] --> YAML serialization --> data/*.yml
      |
      v
[setWindows.swift] YAML parse --> app/window matching --> AXUIElement set
```

## System Requirements

| Item | Requirement |
|------|-------------|
| OS | macOS 15.0 (Sequoia) or later |
| Swift | 5.10 or later |
| Frameworks | SwiftUI, AppKit, CoreGraphics |
| Permission | Accessibility permission required |

## Interface Options

fWarrange can be used in 4 ways:

1. **GUI App** - Menu bar resident app for one-click capture/restore
2. **CLI Scripts** - Run Swift scripts directly from terminal
3. **REST API** - HTTP calls via curl, Apple Shortcuts, automation scripts
4. **AI Integration** - Control via Claude Code Skill or MCP server

## Next Steps

- [Installation & Permissions](02_Install.md)
- [Quick Start](03_QuickStart.md)
