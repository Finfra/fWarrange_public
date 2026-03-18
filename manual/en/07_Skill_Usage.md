# Claude Code Skill Usage

fWarrange integrates with the Claude Code Skill system, enabling AI agents to manage window layouts via natural language.

## Overview

The Claude Code Skill uses the `/fwarrange:fwarrange` slash command to invoke the fWarrange REST API. Users can capture and restore layouts without typing curl commands directly.

## Prerequisites

1. **fWarrange app running** (REST API server enabled)
2. **Claude Code** installed and running
3. **fwarrange Skill** installed

## Installation

### Method 1: Claude Code Plugin Install (Recommended)

```bash
claude plugin install --from https://github.com/nowage/fWarrange --path _public/agents/claude
```

After installation, the skill is auto-registered via `.claude-plugin/plugin.json`.

### Method 2: Manual Copy

Copy the Skill file to your project's `.claude/commands/skills/` directory:

```bash
cp _public/agents/claude/skills/fwarrange/SKILL.md \
   <YOUR_PROJECT>/.claude/commands/skills/fwarrange.md
```

### Method 3: Global Install

To use across all projects, copy to the global commands directory:

```bash
cp _public/agents/claude/skills/fwarrange/SKILL.md \
   ~/.claude/commands/fwarrange.md
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

## Execution Flow

```
User: /fwarrange:fwarrange capture --name=dev
         |
Claude Code: Check server status (GET /)
         |
         +-- Server not responding --> "Please launch fWarrange app" message
         |
         +-- Server OK --> POST /api/v1/capture call
         |
         +-- Report: "Saved 12 windows as 'dev' layout"
```

## When Server Is Not Running

If the server doesn't respond, Claude will display:

> "fWarrange REST API server is not running. Launch the app with:"
> ```bash
> open -a "fWarrange"
> ```
> "Let me know when ready."

Claude will **not** start the server automatically. It waits for user confirmation.

## Skill API Reference

REST API endpoints called internally by the Skill:

| Command | API Call |
|---------|----------|
| `capture` | POST `/api/v1/capture` |
| `restore <name>` | POST `/api/v1/layouts/{name}/restore` |
| `list` | GET `/api/v1/layouts` |
| `status` | GET `/api/v1/status/accessibility` |
| `windows` | GET `/api/v1/windows/current` |
| `apps` | GET `/api/v1/windows/apps` |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--name=<name>` | Layout name for capture/restore | Auto-generated |
| `--server=<URL>` | Change server address | `http://localhost:3016` |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Server not responding" | Verify fWarrange app is running with API server enabled |
| Skill not found | Check install path (`~/.claude/commands/` or project `.claude/`) |
| Restore failure | Check Accessibility permission (`/fwarrange:fwarrange status`) |

## Next Steps

- [MCP Server Usage](08_MCP_Usage.md)
- [FAQ](09_FAQ.md)
