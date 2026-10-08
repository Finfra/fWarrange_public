---
title: fWarrangeCli Skill Usage
description: fWarrangeCli Skill usage (English)
date: 2026.10.08
---
# Claude Code Skill Usage

fWarrangeCli integrates with the Claude Code Skill system, enabling AI agents to manage window layouts via natural language. The Skill only uses the fWarrangeCli REST API, so the GUI wrapper fWarrange is not required.

## Overview

The Claude Code Skill uses the `/fwarrange:fwarrange` slash command to invoke the fWarrangeCli REST API (v2). Users can capture and restore layouts without typing curl commands directly.

## Prerequisites

1. **fWarrangeCli running** (the REST API server is enabled by default — [Installation](02_Install.md#5-check-the-rest-api))
2. **Claude Code** installed and running
3. **fwarrange Skill** installed

## Installation

The Skill is distributed from `fWarrange/` in the unified plugin repository [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins).

### Method 1: Plugin Marketplace (Recommended)

In Claude Code:

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fwarrange@f-claude-plugins
```

### Method 2: Manual Copy

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
mkdir -p .claude-plugin .claude
cp f-claude-plugins/fWarrange/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fWarrange/skills .claude/skills
```

## Usage Examples

### Capture Layout

```
/fwarrange:fwarrange capture
/fwarrange:fwarrange capture --name=coding-setup
```

Claude saves the current window arrangement.

### Restore Layout

```
/fwarrange:fwarrange restore my-workspace
```

Restores windows to their saved positions.

### List Layouts

```
/fwarrange:fwarrange list
```

Displays all saved layouts with names, window counts, and dates.

### Check Permission Status

```
/fwarrange:fwarrange status
```

Checks the Accessibility permission status.

### Current Windows

```
/fwarrange:fwarrange windows
```

Shows information about all currently open windows.

### Running Apps

```
/fwarrange:fwarrange apps
```

Lists all currently running GUI applications.

### Layout Detail

```
/fwarrange:fwarrange detail my-workspace
```

Shows all window positions and sizes for a specific layout.

### Rename Layout

```
/fwarrange:fwarrange rename old-name new-name
```

Renames a saved layout.

### Delete Layout

```
/fwarrange:fwarrange delete my-workspace
```

Deletes a specific layout.

### Delete All Layouts

```
/fwarrange:fwarrange delete-all
```

Deletes all saved layouts. Claude will ask for user confirmation before executing.

### Remove Specific Windows

```
/fwarrange:fwarrange remove-windows my-workspace 14205 5032
```

Removes specific windows from a layout by Window ID.

### Locale Settings

```
/fwarrange:fwarrange locale
/fwarrange:fwarrange locale --set=en
```

Get or change the app display language.

## Execution Flow

```
User: /fwarrange:fwarrange capture --name=dev
         |
Claude Code: Check server status (GET /)
         |
         +-- Server not responding --> fWarrangeCli start command message
         |
         +-- Server OK --> POST /api/v2/capture call
         |
         +-- Report: "Saved 12 windows as 'dev' layout"
```

## When Server Is Not Running

If the server doesn't respond, Claude will display:

> "fWarrange REST API server (fWarrangeCli) is not running. Start it via Homebrew:"
> ```bash
> brew services start finfra/tap/fwarrange-cli
> ```
> "Let me know when ready."

Claude will **not** start the server automatically. It waits for user confirmation.

## Skill API Reference

REST API endpoints called internally by the Skill:

| Command                          | API Call                                     |
| -------------------------------- | -------------------------------------------- |
| `capture`                        | POST `/api/v2/capture`                       |
| `restore <name>`                 | POST `/api/v2/layouts/{name}/restore`        |
| `list`                           | GET `/api/v2/layouts`                        |
| `detail <name>`                  | GET `/api/v2/layouts/{name}`                 |
| `rename <name> <newName>`        | PUT `/api/v2/layouts/{name}`                 |
| `delete <name>`                  | DELETE `/api/v2/layouts/{name}`              |
| `delete-all`                     | DELETE `/api/v2/layouts`                     |
| `remove-windows <name> <ids...>` | POST `/api/v2/layouts/{name}/windows/remove` |
| `status`                         | GET `/api/v2/status/accessibility`           |
| `windows`                        | GET `/api/v2/windows/current`                |
| `apps`                           | GET `/api/v2/windows/apps`                   |
| `locale`                         | GET `/api/v2/settings/general`               |

## Options

| Option           | Description                     | Default                 |
| ---------------- | ------------------------------- | ----------------------- |
| `--name=<name>`  | Layout name for capture/restore | Auto-generated          |
| `--server=<URL>` | Change server address           | `http://localhost:3016` |

## Troubleshooting

| Issue                   | Solution                                                         |
| ----------------------- | ---------------------------------------------------------------- |
| "Server not responding" | Check that fWarrangeCli is running and `restServerEnabled` in `_config.yml` |
| Skill not found         | Check install path (`~/.claude/commands/` or project `.claude/`) |
| Restore failure         | Check Accessibility permission (`/fwarrange:fwarrange status`)   |

## Next Steps

* [MCP Server Usage](07_MCP_Usage.md)
* [FAQ](08_FAQ.md)
