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
/fwarrange:fwarrange status
/fwarrange:fwarrange windows
```

**Features:**
- Guides user to launch fWarrange.app if server is not running
- Capture current window layout with optional name
- Restore saved layouts by name
- List all saved layouts
- Check accessibility permission status
- View current windows and running apps

**Options:**

| Option              | Description           | Default                 |
| ------------------- | --------------------- | ----------------------- |
| `--name=<name>`     | Layout name           | Auto-generated          |
| `--server=<url>`    | Change server address | `http://localhost:3016` |

**API Summary:**

| Method | Endpoint                         | Description            |
| ------ | -------------------------------- | ---------------------- |
| POST   | `/api/v1/capture`                | Capture current layout |
| POST   | `/api/v1/layouts/{name}/restore` | Restore a layout       |
| GET    | `/api/v1/layouts`                | List all layouts       |
| GET    | `/api/v1/layouts/{name}`         | Get layout details     |
| PUT    | `/api/v1/layouts/{name}`         | Rename a layout        |
| DELETE | `/api/v1/layouts/{name}`         | Delete a layout        |
| GET    | `/api/v1/windows/current`        | List current windows   |
| GET    | `/api/v1/windows/apps`           | List running apps      |
| GET    | `/api/v1/status/accessibility`   | Check permissions      |
| GET    | `/api/v1/locale`                 | Get locale setting     |
| PUT    | `/api/v1/locale`                 | Change locale setting  |

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
cp -r _public/agents/claude/.claude-plugin .claude-plugin
cp -r _public/agents/claude/skills .claude/skills
```

### Option 3: Symbolic Link

```bash
ln -sf _public/agents/claude/skills/fwarrange .claude/skills/fwarrange
```

---

## Prerequisites

The fWarrange REST API server must be running:

| Server           | How to Run                                        |
| ---------------- | ------------------------------------------------- |
| macOS Native App | Launch fWarrange.app (REST API enabled by default) |

> If the server is not running, the skill will prompt the user to launch fWarrange.app.

**macOS Accessibility Permission** is required for window restore functionality:
- System Settings > Privacy & Security > Accessibility > Add fWarrange.app

---

## Related Extensions

| Extension                 | Location       | Description                                             |
| ------------------------- | -------------- | ------------------------------------------------------- |
| [MCP Server](../../mcp/) | `_public/mcp/` | Window layout management via MCP protocol (Claude Desktop compatible) |

---

## License

MIT
