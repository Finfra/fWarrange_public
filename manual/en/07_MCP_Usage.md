# MCP Server Usage

fWarrange provides an **MCP (Model Context Protocol)** server, enabling AI tools like Claude Desktop and Claude Code to invoke fWarrange features as native tools.

## What is MCP?

MCP (Model Context Protocol) is a standard protocol for AI models to interact with external tools. With the fWarrange MCP server configured, an AI can autonomously call the appropriate tool when asked to "save my window layout."

### Skill vs MCP

| Aspect | Claude Code Skill | MCP Server |
|--------|-------------------|------------|
| Mechanism | Slash command -> curl calls | AI directly invokes Tools |
| Install Location | `.claude/commands/` | `claude_desktop_config.json` |
| Invocation | `/fwarrange:fwarrange capture` | AI decides automatically |
| Supported Clients | Claude Code | Claude Desktop, Claude Code, etc. |
| Natural Language | Command-based | Full natural language |

## Prerequisites

1. **fWarrange app running** (REST API server enabled)
2. **Node.js** 18 or later
3. **npm** installed

## Installation

### npm Package Install

```bash
npm install -g fwarrange-mcp
```

### Build from Source

```bash
cd mcp
npm install
npm run build
```

## Configuration

### Claude Desktop Setup

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp"],
      "env": {
        "FWARRANGE_API_URL": "http://localhost:3016"
      }
    }
  }
}
```

### Claude Code Setup

Add to `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "npx",
      "args": ["-y", "fwarrange-mcp"],
      "env": {
        "FWARRANGE_API_URL": "http://localhost:3016"
      }
    }
  }
}
```

### Custom Server Address

To use a different server address, add the `--server=` option to `args`:

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

```bash
npm install -g fwarrange-mcp
```

```json
{
  "mcpServers": {
    "fwarrange": {
      "command": "fwarrange-mcp"
    }
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FWARRANGE_API_URL` | `http://localhost:3016` | fWarrange REST API server address |

## Available Tools (14)

The MCP server provides the following tools to AI:

### Status

| Tool | Description |
|------|-------------|
| `health_check` | Check server status and version |
| `check_accessibility` | Check Accessibility permission status |

### Layout Management

| Tool | Description | Parameters |
|------|-------------|------------|
| `list_layouts` | List saved layouts | - |
| `get_layout` | Get specific layout details | `name` |
| `capture_layout` | Capture and save current windows | `name?`, `filterApps?` |
| `restore_layout` | Restore a saved layout | `name`, `maxRetries?`, `retryInterval?`, `minimumScore?` |
| `rename_layout` | Rename a layout | `name`, `newName` |
| `delete_layout` | Delete a layout | `name` |
| `delete_all_layouts` | Delete all layouts | - |
| `remove_windows` | Remove specific windows from a layout | `name`, `windowIds` |

### Window Queries

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_current_windows` | List current windows (without saving) | `filterApps?` |
| `get_running_apps` | List running applications | - |

### System Settings

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_locale` | Get current language setting | - |
| `set_locale` | Change app language | `language` |

## Usage Examples

Once MCP is configured, simply ask in natural language:

### Capture Layout
> "Save my current window arrangement as coding-setup"

Claude calls `capture_layout` to save.

### Restore Layout
> "Restore the coding-setup layout"

Claude calls `restore_layout`.

### Check Status
> "What layouts do I have saved?"

Claude calls `list_layouts` and shows the results.

### Composite Operations
> "Save just Safari's position, then restore my meeting layout"

Claude calls `capture_layout(filterApps: ["Safari"])` then `restore_layout(name: "meeting")` sequentially.

## Communication Protocol

```
Claude Desktop/Code  <--stdio-->  fwarrange-mcp  <--HTTP-->  fWarrange App
                                   (Node.js)                  (REST API :3016)
```

- AI client to MCP server: **stdio** (standard I/O)
- MCP server to fWarrange app: **HTTP** (REST API)

## Debugging

### Test with MCP Inspector

Use the MCP Inspector to interactively test each tool in the browser:

```bash
npx @modelcontextprotocol/inspector npx fwarrange-mcp
```

### Verify Server Connection

```bash
# Check if the fWarrange REST API server is running
curl http://localhost:3016/
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MCP server not connecting | Check `claude_desktop_config.json` path and JSON syntax |
| "Server not responding" | Verify fWarrange app is running with REST API enabled |
| Tools not appearing | Restart Claude Desktop, or run `npx fwarrange-mcp` directly to check errors |
| Permission errors | Check Accessibility permission (use `check_accessibility` tool) |
| Port conflict | Change port via `--server=` option or `FWARRANGE_API_URL` environment variable |

## Next Steps

- [FAQ](08_FAQ.md)
- [REST API Reference](05_API_Usage.md)
