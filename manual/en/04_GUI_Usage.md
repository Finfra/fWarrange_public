# GUI Usage

fWarrange runs as a SwiftUI menu bar app on macOS, allowing one-click layout management.

## Main Screen

Click the menu bar icon to view the layout list and primary controls.

![Main Screen](https://finfra.kr/product/fWarrange/en/main_1.png)

![Main Screen Full](https://finfra.kr/product/fWarrange/en/main_all.png)

### Key Functions
- **Capture Button**: Save current window arrangement as a new layout
- **Layout List**: Select and restore saved layouts
- **Delete**: Remove a layout
- **Rename**: Edit layout name

## Settings (5 Tabs)

Open the settings window via the menu bar > settings icon.

### Tab 1: General

![General Settings](https://finfra.kr/product/fWarrange/en/setting_1_general.png)

| Item | Description |
|------|-------------|
| Language | App display language (System, English, Korean, Japanese, etc.) |
| Data Path | YAML layout file storage location |
| Permission Status | Accessibility permission verification |
| Auto Launch | Start automatically on macOS login |
| Theme | System / Light / Dark mode |

### Tab 2: Shortcuts

![Shortcuts Settings](https://finfra.kr/product/fWarrange/en/setting_2_shortcuts.png)

5 customizable global shortcuts:

| Function | Default | Description |
|----------|---------|-------------|
| Capture | - | Save current window arrangement |
| Restore | - | Restore last layout |
| List | - | Show layout selection window |
| Toggle Popup | - | Toggle menu bar popup |
| Settings | - | Open settings window |

### Tab 3: Restore

![Restore Settings](https://finfra.kr/product/fWarrange/en/setting_3_restore.png)

| Item | Default | Description |
|------|---------|-------------|
| Max Retries | 5 | Maximum retry count on match failure |
| Retry Interval | 0.5s | Wait time between retries |
| Minimum Score | 30 | Matches below this score are ignored |
| Excluded Apps | System apps | Apps excluded from capture/restore |

**Default Excluded Apps:**
- Window Server, Control Center, Presentation Assistant
- Dock, SystemUIServer, Spotlight

### Tab 4: API

![API Settings](https://finfra.kr/product/fWarrange/en/setting_4_api.png)

| Item | Default | Description |
|------|---------|-------------|
| Enable Server | OFF | Start/stop REST API server |
| Port | 3016 | HTTP listening port |
| Allow External | OFF | Allow LAN/WAN access |
| Allowed CIDR | 192.168.0.0/16 | IP whitelist |

### Tab 5: Advanced

![Advanced Settings](https://finfra.kr/product/fWarrange/en/setting_5_advanced.png)

| Item | Description |
|------|-------------|
| Log Settings | Enable/disable debug logging |
| Dangerous Zone | Delete all layouts, reset settings |

## Typical Usage Flow

1. Click menu bar icon
2. Click "Capture" to save current arrangement
3. Select a layout from the list to restore when needed

## Next Steps

- [REST API Usage](05_API_Usage.md)
- [Skill Usage](06_Skill_Usage.md)
- [MCP Server Usage](07_MCP_Usage.md)
