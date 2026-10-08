---
title: fWarrangeCli Quick Start
description: fWarrangeCli quick start — save · move · restore in 3 steps (English)
date: 2026.10.08
---
# Quick Start

The core flow is **save → (windows get scattered) → restore**. You can do the same thing from the menu bar, a shortcut, the command line, or the REST API.

## Step 1: Save the Current Arrangement

Arrange your windows the way you want, then save.

| Method       | How                                                                                                                 |
| ------------ | ------------------------------------------------------------------------------------------------------------------- |
| Menu bar     | Icon › **📷 Save Window Layout** (named `YYYY-MM-DD-N` automatically)                                               |
| Shortcut     | ⌘F7                                                                                                                 |
| Command line | `fWarrangeCli capture myWorkspace`                                                                                  |
| API          | `curl -X POST http://localhost:3016/api/v2/capture -H "Content-Type: application/json" -d '{"name":"myWorkspace"}'` |

## Step 2: Windows Move

Your windows got scattered while working, or you switched to another arrangement and want to come back.

## Step 3: Restore the Saved Arrangement

| Method       | How                                                                     |
| ------------ | ----------------------------------------------------------------------- |
| Menu bar     | Icon › click a layout name (or **🔁 Restore Last Layout**)              |
| Shortcut     | ⌥⌘F7 (last) · ⇧⌘F7 (default layout)                                     |
| Command line | `fWarrangeCli restore myWorkspace`                                      |
| API          | `curl -X POST http://localhost:3016/api/v2/layouts/myWorkspace/restore` |

With a Homebrew install, `fWarrangeCli` on the command line is `/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app/Contents/MacOS/fWarrangeCli` — see [Menu Bar Usage › Command Line](04_MenuBar_Usage.md#command-line-cli).

## Examples (REST API)

### Switch Layouts per Task

```bash
# Save
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" -d '{"name":"coding"}'
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" -d '{"name":"meeting"}'

# Switch
curl -X POST http://localhost:3016/api/v2/layouts/coding/restore
curl -X POST http://localhost:3016/api/v2/layouts/meeting/restore
```

### Save Specific Apps Only

```bash
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"webDev", "filterApps":["Safari","iTerm2"]}'
```

### Manage Layouts

```bash
curl -s http://localhost:3016/api/v2/layouts                  # list
curl -s http://localhost:3016/api/v2/layouts/myWorkspace      # details
curl -X PUT http://localhost:3016/api/v2/layouts/myWorkspace \
  -H "Content-Type: application/json" -d '{"newName":"dailySetup"}'   # rename
curl -X DELETE http://localhost:3016/api/v2/layouts/dailySetup        # delete
```

## Prefer a GUI?

A GUI for picking layouts from a list and minimap and restoring only the checked windows is provided by the wrapper app **fWarrange** — see the [fWarrange product page](https://finfra.kr/product/fWarrange/en/index.html).

## Next Steps

* [Menu Bar Usage](04_MenuBar_Usage.md) — menu · shortcuts · command line · `_config.yml`
* [REST API Usage](05_API_Usage.md) — all endpoints
* [Skill Usage](06_Skill_Usage.md) — natural-language control from Claude Code
* [MCP Server Usage](07_MCP_Usage.md) — AI tool integration
