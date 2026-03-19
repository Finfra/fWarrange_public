# fWarrange Claude Code Plugin

A Claude Code plugin that saves and restores macOS window layouts via the fWarrange REST API.
After installation, manage window layouts instantly using slash commands in Claude Code.

---

## Plugin Structure

```
.claude-plugin/
└── plugin.json              # Plugin manifest
skills/
└── fwarrange/
    └── SKILL.md             # Window layout management skill
```

---

## Skills

### `fwarrange` — Window Layout Management

Save and restore macOS window positions and sizes via the fWarrange REST API.

**Usage:**
```
/fwarrange:fwarrange capture
/fwarrange:fwarrange capture --name=coding-setup
/fwarrange:fwarrange restore my-workspace
/fwarrange:fwarrange list
/fwarrange:fwarrange detail my-workspace
/fwarrange:fwarrange rename old-name new-name
/fwarrange:fwarrange delete my-workspace
/fwarrange:fwarrange delete-all
/fwarrange:fwarrange remove-windows my-workspace 14205 5032
/fwarrange:fwarrange windows
/fwarrange:fwarrange apps
/fwarrange:fwarrange status
/fwarrange:fwarrange locale
/fwarrange:fwarrange locale --set=en
```

**Features:**
- Guides user to launch fWarrange.app if server is not running
- Capture current window layout with optional name and app filter
- Restore saved layouts with customizable retry settings
- List all saved layouts with metadata
- Get detailed layout information (window positions, sizes)
- Rename and delete layouts
- Delete all layouts (with safety confirmation)
- Remove specific windows from a layout by ID
- View current windows and running apps
- Check accessibility permission status
- Get and change app locale/language

**Options:**

| Option              | Description           | Default                 |
| ------------------- | --------------------- | ----------------------- |
| `--name=<name>`     | Layout name           | Auto-generated          |
| `--server=<url>`    | Change server address | `http://localhost:3016` |
| `--set=<code>`      | Set locale language   | -                       |

**API Summary (14 Endpoints):**

| Method | Endpoint                                | Description                  |
| ------ | --------------------------------------- | ---------------------------- |
| GET    | `/`                                     | Health check                 |
| GET    | `/api/v1/layouts`                       | List all layouts             |
| DELETE | `/api/v1/layouts`                       | Delete all layouts (*)       |
| GET    | `/api/v1/layouts/{name}`                | Get layout details           |
| PUT    | `/api/v1/layouts/{name}`                | Rename a layout              |
| DELETE | `/api/v1/layouts/{name}`                | Delete a layout              |
| POST   | `/api/v1/capture`                       | Capture current layout       |
| POST   | `/api/v1/layouts/{name}/restore`        | Restore a layout             |
| POST   | `/api/v1/layouts/{name}/windows/remove` | Remove specific windows      |
| GET    | `/api/v1/windows/current`               | List current windows         |
| GET    | `/api/v1/windows/apps`                  | List running apps            |
| GET    | `/api/v1/status/accessibility`          | Check permissions            |
| GET    | `/api/v1/locale`                        | Get locale setting           |
| PUT    | `/api/v1/locale`                        | Change locale setting        |

(*) Requires `X-Confirm-Delete-All: true` header.

---

## Installation

### Option 1: Plugin Install (Recommended)

```bash
/plugin marketplace add nowage/fWarrange
/plugin install fwarrange
```

### Option 2: Manual Copy

Copy the plugin directory to your project:

```bash
# From fWarrange project root
cp -r agents/claude/.claude-plugin .claude-plugin
cp -r agents/claude/skills .claude/skills
```

### Option 3: Symbolic Link

```bash
ln -sf agents/claude/skills/fwarrange .claude/skills/fwarrange
```

---

## Prerequisites

The fWarrange REST API server must be running:

| Server           | How to Run                                        |
| ---------------- | ------------------------------------------------- |
| macOS Native App | Launch fWarrange.app (REST API is disabled by default. Enable it in Settings > API tab) |

> If the server is not running, the skill will prompt the user to launch fWarrange.app.

**macOS Accessibility Permission** is required for window restore functionality:
- System Settings > Privacy & Security > Accessibility > Add fWarrange.app

---

## Related Extensions

| Extension                 | Location       | Description                                             |
| ------------------------- | -------------- | ------------------------------------------------------- |
| [MCP Server](../../mcp/) | `mcp/` | Window layout management via MCP protocol (Claude Desktop compatible) |

---

## License

MIT
