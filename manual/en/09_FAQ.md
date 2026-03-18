# Frequently Asked Questions (FAQ)

## General

### Q: Is fWarrange free?
A: Yes, fWarrange is an open-source project under the MIT license.

### Q: Which macOS versions are supported?
A: macOS 15.0 (Sequoia) and later.

### Q: Does it support Apple Silicon (M1/M2/M3/M4)?
A: Yes, natively supported.

## Permissions

### Q: I get an "Accessibility permission required" error.
A: Go to System Settings > Privacy & Security > Accessibility and add fWarrange (or your terminal app). See the [Installation Guide](02_Install.md#3-accessibility-permission-setup) for details.

### Q: Permissions are lost after each rebuild.
A: Xcode generates a different binary signature with each build, so macOS treats it as a new app. During development, re-registration is needed each time. Release builds with stable signing resolve this.

### Q: What does `tccutil reset Accessibility` do?
A: It resets all Accessibility permissions for all apps. You'll need to re-register required apps afterward.

## Layout Save/Restore

### Q: Window restore fails.
A: Check the following:
1. Accessibility permission is granted
2. The app you're trying to restore is running
3. Use the `-v` option to check matching scores and identify failing windows

### Q: Window positions are slightly off after restore.
A: Restore verification allows a 3px tolerance. Some apps (especially Electron-based) may not support exact positioning due to system constraints.

### Q: Negative coordinates appear in multi-monitor setups.
A: This is normal. In macOS coordinates, secondary monitors placed to the left of the main monitor have negative coordinates. These are handled correctly during save and restore.

### Q: What happens if I change display arrangement?
A: Changing monitor arrangement in System Settings may cause previously saved coordinates to point to incorrect positions. Re-saving layouts after arrangement changes is recommended.

### Q: Can I save/restore only specific app windows?
A: Yes, use the `--app=Safari,iTerm2` CLI option or the `filterApps` API field.

### Q: Are full-screen apps restored?
A: Full-screen apps run in separate Spaces, so coordinate-based restoration does not apply to them.

## REST API

### Q: Why is the API server disabled by default?
A: For security. Opening an HTTP server exposes it to local network attacks, so it's designed to be manually activated only when needed.

### Q: Can I access from an external network?
A: Enable external access in Settings > API tab and configure the CIDR whitelist. LAN access is possible, but direct internet exposure is not recommended.

### Q: Can I change the port?
A: Yes, via Settings > API tab. Default is 3016.

### Q: How do I call from Apple Shortcuts?
A: Use the "Get Contents of URL" action in Shortcuts with `http://localhost:3016/api/v1/layouts/myLayout/restore` as a POST request. See [API Usage](06_API_Usage.md#apple-shortcuts-integration) for details.

## Skill / MCP

### Q: What's the difference between Skill and MCP?
A:
- **Skill**: Invoked via `/fwarrange:fwarrange` slash command in Claude Code. Internally executes curl commands.
- **MCP**: AI automatically selects and invokes the appropriate tool in Claude Desktop/Code. Full natural language support.

### Q: Can I use Skill and MCP simultaneously?
A: Yes, they operate independently. Skill uses explicit commands, MCP uses natural language.

### Q: MCP server won't connect.
A: Check:
1. fWarrange app is running with REST API enabled
2. `claude_desktop_config.json` has valid JSON syntax
3. Node.js 18+ is installed
4. Run `npx fwarrange-mcp` directly to see error messages

### Q: Can I use Skill/MCP without the fWarrange app?
A: No. Both Skill and MCP work through fWarrange's REST API server. The app must be running.

## Performance

### Q: Is restore slow with many windows?
A: Per-app parallel restore (`enableParallel: true`) is enabled by default, so 20-30 windows are restored within seconds.

### Q: Will YAML files get too large?
A: In typical use, YAML files are under a few dozen KB. Periodically deleting unused layouts is recommended.

## Related Documents

- [Product Overview](01_Overview.md)
- [Installation Guide](02_Install.md)
- [GUI Usage](04_GUI_Usage.md)
- [CLI Usage](05_CLI_Usage.md)
- [REST API Usage](06_API_Usage.md)
- [Skill Usage](07_Skill_Usage.md)
- [MCP Server Usage](08_MCP_Usage.md)
