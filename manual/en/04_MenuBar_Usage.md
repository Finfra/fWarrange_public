---
title: fWarrangeCli Menu Bar Usage
description: fWarrangeCli menu bar · global shortcuts · command line · _config.yml (English)
date: 2026.10.08
---
# Menu Bar Usage

fWarrangeCli lives in the menu bar as a single icon. Saving and restoring windows, managing the daemon (REST server), and opening the configuration file are all done from this menu. GUI features such as the layout list, minimap, and settings window belong to the wrapper app **fWarrange** — see the [fWarrange product page](https://finfra.kr/product/fWarrange/en/index.html).

## Menu Items

| Menu                               | Default shortcut | Action                                                                                                    |
| ---------------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------- |
| ℹ️ About fWarrangeCli               | -                | Version info. Becomes **About fWarrange** while fWarrange is running                                      |
| 🔁 Restore Last Layout             | ⌥⌘F7             | Restore the most recently used layout                                                                     |
| ⭐ Restore Default Layout          | ⇧⌘F7             | Restore the default layout                                                                                |
| (layout list)                      | -                | Default layout (`⭐ name   Default`) + 5 most recent. Click to restore. The rest show as `...and N more`  |
| 🖥️ Open Main Window                 | ⌃⇧⌘F7            | Show the fWarrange main window — **requires fWarrange**                                                   |
| 📷 Save Window Layout              | ⌘F7              | Save the current arrangement as `YYYY-MM-DD-N`                                                            |
| 👻 Daemon ▸ Status                 | -                | `Status: Running · Port 3016 · Uptime …`                                                                  |
| 👻 Daemon ▸ Restart Daemon         | -                | Restart the REST server                                                                                   |
| 👻 Daemon ▸ Pause REST API         | -                | Temporarily reject REST requests (click again for **Resume REST API**). fWarrange also stops while paused |
| ⚙️ Configuration ▸ Settings…        | -                | Open the fWarrange settings window — **requires fWarrange**                                               |
| ⚙️ Configuration ▸ Open Config File | -                | Select `_config.yml` in Finder                                                                            |
| ⚙️ Configuration ▸ Open Data Folder | -                | Open the folder containing layout YAML files                                                              |
| ⚙️ Configuration ▸ Open Log Folder  | -                | `~/Documents/finfra/fWarrangeData/logs/` (`wlog_cliApp.log`)                                              |
| 🚀 Launch at Login                 | -                | Toggle with the checkmark                                                                                 |
| Quit fWarrangeCli                  | -                | Shown while fWarrange is not running                                                                      |
| Quit fWarrange · Quit All          | ⌘Q · -           | Shown while fWarrange is running. **Quit fWarrange** quits fWarrange only; **Quit All** quits both apps   |

* The menu language follows `appLanguage` in `_config.yml` (default `system`)
* **Open Main Window** and **Settings…** open fWarrange. If fWarrange is not installed, a prompt offers **App Store** · **Browse** · **Cancel**
* Shortcuts work anywhere without opening the menu (global shortcuts). Shortcuts that move windows need the Accessibility permission

## Global Shortcuts

| `_config.yml` key        | Default | Action                                    |
| ------------------------ | ------- | ----------------------------------------- |
| `saveShortcut`           | `⌘F7`   | Save window layout                        |
| `restoreDefaultShortcut` | `⇧⌘F7`  | Restore default layout                    |
| `restoreLastShortcut`    | `⌥⌘F7`  | Restore last layout                       |
| `showMainWindowShortcut` | `⌃⇧⌘F7` | fWarrange main window                     |
| `undoShortcut`           | (none)  | Return to the previous window arrangement |

Symbols: `⌃`=Control · `⌥`=Option · `⇧`=Shift · `⌘`=Command. Removing a line unregisters that shortcut. With fWarrange you can also change them in Settings › Shortcuts.

## Configuration File `_config.yml`

Location: `~/Documents/finfra/fWarrangeData/_config.yml` (menu **Configuration ▸ Open Config File**). All fWarrangeCli settings live in this one file, and the fWarrange settings window edits it too.

| Key                                                  | Default                               | Description                                                      |
| ---------------------------------------------------- | ------------------------------------- | ---------------------------------------------------------------- |
| `excludedApps`                                       | `Activity Monitor`, `System Settings` | Apps excluded from capture/restore                               |
| `maxRetries` · `retryInterval`                       | `5` · `0.5`                           | Retries and interval (sec) when a window move cannot be verified |
| `minimumMatchScore`                                  | `30`                                  | Window matches below this score are ignored                      |
| `restServerEnabled` · `restServerPort`               | `true` · `3016`                       | Enable the REST API server · port                                |
| `allowExternalAccess` · `allowedCIDR`                | `false` · `192.168.0.0/16`            | Allow external (LAN) access · allowed IP range                   |
| `dataStorageMode`                                    | `host`                                | `host`: per-machine subfolder · `share`: shared by several Macs  |
| `launchAtLogin` · `appLanguage`                      | `true` · `system`                     | Launch at login · menu language                                  |
| `autoSaveOnSleep` · `maxAutoSaves` · `retentionDays` | `true` · `5` · `7`                    | Auto-save on sleep · number kept · days kept                     |
| `logLevel`                                           | `5`                                   | 0=verbose … 5=critical                                           |

## Command Line (CLI)

Passing arguments to the fWarrangeCli executable sends a REST request to the running daemon and prints the result. With a Homebrew install the path is:

```bash
FWC=/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app/Contents/MacOS/fWarrangeCli

$FWC status                 # daemon status
$FWC list                   # list layouts
$FWC capture myWorkspace    # save the current arrangement
$FWC restore myWorkspace    # restore (defaults to 'default')
$FWC show myWorkspace       # layout details
$FWC accessibility          # check Accessibility permission
$FWC --help                 # all commands (rename · delete · windows · apps · mode · v2 settings, etc.)
```

Options: `--port <port>` (default 3016) · `--host <host>` · `--pretty` (pretty JSON) · `-q` (exit code only).

## Next Steps

* [REST API Usage](05_API_Usage.md)
* [Claude Code Skill Usage](06_Skill_Usage.md)
* [MCP Server Usage](07_MCP_Usage.md)
* GUI (layout list · minimap · settings window): [fWarrange product page](https://finfra.kr/product/fWarrange/en/index.html)
