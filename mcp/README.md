# fWarrange MCP Server

An [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server that exposes the fWarrange REST API as tools.
Manage macOS window layouts directly from AI agents such as Claude Code and Claude Desktop.

## Prerequisites

The fWarrange REST API server must be running:

| Server           | How to Run                                       |
| ---------------- | ------------------------------------------------ |
| macOS Native App | Launch fWarrange.app (enable REST API in Settings) |

Default server address: `http://localhost:3016`

---

## Installation

### Option 1: Global Install (Recommended)

```bash
npm install -g fwarrange-mcp
```

[![npm](https://img.shields.io/npm/v/fwarrange-mcp)](https://www.npmjs.com/package/fwarrange-mcp)

### Option 2: npx (No Installation Required)

Run directly via `npx` in your MCP configuration.

### Option 3: From Source

```bash
git clone https://github.com/nowage/fWarrange.git
cd fWarrange/mcp
npm install
```

---

## Configuration

### Claude Code

* Add to `~/.claude/settings.json` or project `.claude/settings.json`:
  - For Claude Desktop, add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp"]
    }
  }
}
```

* If running from source:
```json
  "mcpServers": {
    "fwarrange": {
      "command": "node",
      "args": [
        "{PROJECT_ROOT-type-or-paste-it}/mcp/index.js"
      ]
    }
  }
```

* To change the server address:
```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp", "--server=http://192.168.0.10:3016"]
    }
  }
}
```

### After Global Install

```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "fwarrange-mcp"
    }
  }
}
```

---

## Tools

### 1. `health_check`

Check the fWarrange server status.

**Parameters**: None

**Response example**:
```json
{
  "status": "ok",
  "app": "fWarrange",
  "port": 3016
}
```

---

### 2. `list_layouts`

List all saved window layouts.

**Parameters**: None

**Response example**:
```json
{
  "layouts": [
    { "name": "work", "windowCount": 8, "fileDate": "2026-03-18T10:00:00Z" },
    { "name": "home", "windowCount": 5, "fileDate": "2026-03-17T20:00:00Z" }
  ]
}
```

---

### 3. `get_layout`

Get detailed window information for a specific layout.

**Parameters**:

| Name   | Type   | Required | Description                     |
| ------ | ------ | -------- | ------------------------------- |
| `name` | string | Yes      | Layout name (without extension) |

**Response example**:
```json
{
  "name": "work",
  "windows": [
    {
      "app": "Safari",
      "window": "Start Page",
      "id": 14205,
      "pos": { "x": 100, "y": 200 },
      "size": { "width": 1200, "height": 800 }
    }
  ]
}
```

---

### 4. `capture_layout`

Capture the current window layout and save it.

**Parameters**:

| Name         | Type     | Required | Description                               |
| ------------ | -------- | -------- | ----------------------------------------- |
| `name`       | string   | No       | Layout name (uses default if omitted)     |
| `filterApps` | string[] | No       | App names to capture (all if omitted)     |

**Usage example** (ask Claude):
```
Capture the current window layout and save it as "work"
```

---

### 5. `restore_layout`

Restore a saved layout to reposition windows.

**Parameters**:

| Name             | Type    | Required | Default | Description                    |
| ---------------- | ------- | -------- | ------- | ------------------------------ |
| `name`           | string  | Yes      | -       | Layout name to restore         |
| `maxRetries`     | number  | No       | 5       | Maximum retry attempts         |
| `retryInterval`  | number  | No       | 0.5     | Retry interval in seconds      |
| `minimumScore`   | number  | No       | 30      | Minimum window matching score  |
| `enableParallel` | boolean | No       | -       | Enable parallel restoration    |

**Usage example** (ask Claude):
```
Restore the "work" layout
```

---

### 6. `rename_layout`

Rename a layout.

**Parameters**:

| Name      | Type   | Required | Description       |
| --------- | ------ | -------- | ----------------- |
| `name`    | string | Yes      | Current name      |
| `newName` | string | Yes      | New name          |

---

### 7. `delete_layout`

Delete a specific layout.

**Parameters**:

| Name   | Type   | Required | Description            |
| ------ | ------ | -------- | ---------------------- |
| `name` | string | Yes      | Layout name to delete  |

---

### 8. `delete_all_layouts`

Delete all saved layouts. Sends `X-Confirm-Delete-All` header automatically.

**Parameters**: None

---

### 9. `remove_windows`

Remove specific windows from a layout by Window ID.

**Parameters**:

| Name        | Type     | Required | Description                |
| ----------- | -------- | -------- | -------------------------- |
| `name`      | string   | Yes      | Layout name                |
| `windowIds` | number[] | Yes      | Window IDs to remove       |

**Usage example** (ask Claude):
```
Remove windows 14205 and 14210 from the "work" layout
```

---

### 10. `get_current_windows`

Get list of currently open windows.

**Parameters**:

| Name         | Type     | Required | Description                           |
| ------------ | -------- | -------- | ------------------------------------- |
| `filterApps` | string[] | No       | App names to filter (all if omitted)  |

**Usage example** (ask Claude):
```
Show me the current windows for Safari and iTerm2
```

---

### 11. `get_running_apps`

Get list of currently running applications.

**Parameters**: None

---

### 12. `check_accessibility`

Check macOS Accessibility permission status.

**Parameters**: None

**Response example**:
```json
{
  "accessible": true
}
```

---

### 13. `get_locale`

Get the current app language and list of supported languages.

**Parameters**: None

**Response example**:
```json
{
  "status": "ok",
  "data": {
    "current": "ko",
    "supported": ["system", "ko", "en", "ja", "ar", "zh-Hans", "zh-Hant", "fr", "de", "hi", "es"]
  }
}
```

---

### 14. `set_locale`

Change the app display language. Requires app restart to take effect.

**Parameters**:

| Name       | Type   | Required | Description                                      |
| ---------- | ------ | -------- | ------------------------------------------------ |
| `language` | string | Yes      | Language code (e.g. "ko", "en", "ja", "system")  |

**Response example**:
```json
{
  "status": "ok",
  "data": {
    "language": "en",
    "restartRequired": true
  }
}
```

---

## Debugging

### Test with MCP Inspector

```bash
npx @modelcontextprotocol/inspector npx fwarrange-mcp
```

Opens the Inspector UI in your browser to test each tool interactively.

### Verify Server Connection

```bash
# Check if the fWarrange REST API server is running
curl http://localhost:3016/
```

---

## Publishing to npm

```bash
cd mcp
npm publish
```

---

## Architecture

```
Claude Code / Claude Desktop
    |
    | MCP (stdio)
    v
fwarrange-mcp (this server)
    |
    | HTTP (REST API)
    v
fWarrange Server (localhost:3016)
    └── macOS Native App (Swift/SwiftUI)
```

---

## License

MIT
