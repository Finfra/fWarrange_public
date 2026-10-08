---
title: fWarrangeCli FAQ
description: fWarrangeCli frequently asked questions (English)
date: 2026.10.08
---
# Frequently Asked Questions (FAQ)

## fWarrangeCli and fWarrange

### Q: How do fWarrangeCli and fWarrange differ?
A: **fWarrangeCli** is the engine that captures and restores windows and runs the shortcuts and REST API (Homebrew, free). **fWarrange** is the **GUI wrapper** on top of it that adds a layout list, minimap, and settings window (App Store, paid). fWarrange works through the fWarrangeCli REST API — see [Overview](01_Overview.md#fwarrangecli-and-fwarrange-gui-wrapper).

### Q: Can I use fWarrangeCli alone, without fWarrange?
A: Yes. The menu bar, global shortcuts, command line, REST API, Skill, and MCP all work with fWarrangeCli alone. The reverse is not true: fWarrange does not work without fWarrangeCli.

### Q: Where is the fWarrange (GUI) guide?
A: See the [fWarrange product page](https://finfra.kr/product/fWarrange/en/index.html). The menu bar items **Open Main Window** and **Settings…** open fWarrange.

### Q: Is fWarrangeCli free?
A: The source code in this repository is open source under Apache-2.0 (the `mcp/` package is MIT) — you can build and use it without limit. Official builds (Homebrew `finfra/tap`, GitHub Releases) are free for personal use, education, non-profits, open-source projects, and other organizations up to 250 concurrent copies; beyond that, or for resale / bundling / hosting, see [COMMERCIAL.md](../../COMMERCIAL.md). Details: [DISTRIBUTION-TERMS.md](../../DISTRIBUTION-TERMS.md) · [TRADEMARK.md](../../TRADEMARK.md). The GUI wrapper fWarrange is a paid App Store app.

### Q: Which macOS versions are supported?
A: fWarrangeCli needs macOS 14.0 or later, fWarrange needs 15.6 or later. Both Apple Silicon and Intel are supported.

## Permissions

### Q: I get an "Accessibility permission required" error.
A: Turn on **fWarrangeCli** in System Settings › Privacy & Security › Accessibility. fWarrange itself needs no permission — see [Installation › Accessibility Permission](02_Install.md#4-accessibility-permission).

### Q: Shortcuts respond but windows don't move.
A: Shortcuts register regardless of the permission, but moving windows requires it. Turn the permission on again and restart fWarrangeCli.

### Q: Permissions are lost after each source build.
A: A new build has a different signature, so macOS treats it as a different app. Register it again after each build. Official Homebrew builds keep a stable signature.

## Layout Save/Restore

### Q: Window restore fails.
A: Check the following:
1. fWarrangeCli has the Accessibility permission
2. The apps you want to restore are running
3. The per-window results in the restore response (REST or command line) show which windows were not matched

### Q: Window positions are slightly off after restore.
A: Restore verification allows a 3px tolerance. Some apps (especially Electron-based ones) cannot be positioned precisely due to system constraints.

### Q: Negative coordinates appear in multi-monitor setups.
A: This is normal. In the macOS coordinate system, secondary monitors placed left of or above the main monitor have negative coordinates.

### Q: What happens if I change the display arrangement?
A: Previously saved coordinates may point to the wrong place. Save your layouts again after rearranging displays.

### Q: Can I save only specific app windows?
A: Yes, use the `filterApps` field of the REST API `capture` — see [Quick Start › Save Specific Apps Only](03_QuickStart.md#save-specific-apps-only).

### Q: Are full-screen apps restored?
A: Full-screen apps run in their own Space, so coordinate-based restore does not apply to them.

## REST API

### Q: Is the API server on?
A: It is on by default (`restServerEnabled: true`, port 3016, `127.0.0.1` only). fWarrange also works through this server, so turning it off stops fWarrange. To block it temporarily, use **Daemon ▸ Pause REST API** in the menu bar.

### Q: Can I access it from an external network?
A: Set `allowExternalAccess: true` and `allowedCIDR` (default `192.168.0.0/16`) in `_config.yml` to allow LAN access. Exposing it directly to the internet is not recommended.

### Q: Can I change the port?
A: Change `restServerPort` in `_config.yml` and restart fWarrangeCli — see [Menu Bar Usage › Configuration File](04_MenuBar_Usage.md#configuration-file-_configyml).

### Q: How do I call it from Apple Shortcuts?
A: Use the Shortcuts "Get Contents of URL" action to POST `http://localhost:3016/api/v2/layouts/myLayout/restore` — see [API Usage](05_API_Usage.md#apple-shortcuts-integration).

## Skill / MCP

### Q: What's the difference between Skill and MCP?
A:
* **Skill**: Invoked in Claude Code with the `/fwarrange:fwarrange` slash command. Runs curl internally
* **MCP**: In Claude Desktop/Code, the AI picks and calls the right tool. Natural-language support

### Q: The MCP server won't connect.
A: Check the following:
1. fWarrangeCli is running and `curl -s http://localhost:3016/api/v2/status` responds
2. The JSON syntax of `claude_desktop_config.json` is valid
3. Node.js 18 or later is installed
4. Run `npx fwarrange-mcp` directly to see the error message

### Q: Do Skill/MCP need fWarrange (GUI)?
A: No. Skill and MCP work through the fWarrangeCli REST API, so fWarrangeCli running is enough.

## Performance

### Q: Is restore slow with many windows?
A: Per-app parallel restore (`enableParallelRestore: true`) is the default, so 20–30 windows are restored within a few seconds.

## Related Documents

* [Overview](01_Overview.md)
* [Installation](02_Install.md)
* [Menu Bar Usage](04_MenuBar_Usage.md)
* [REST API Usage](05_API_Usage.md)
* [Skill Usage](06_Skill_Usage.md)
* [MCP Server Usage](07_MCP_Usage.md)
* [fWarrange (GUI) product page](https://finfra.kr/product/fWarrange/en/index.html)
