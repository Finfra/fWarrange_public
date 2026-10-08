---
title: fWarrangeCli Installation
description: fWarrangeCli installation · Accessibility permission · REST API check (English)
date: 2026.10.08
---
# Installation & Permissions

## 1. System Requirements

| Item        | Requirement                             |
| ----------- | --------------------------------------- |
| macOS       | 14.0 or later                           |
| Install     | Homebrew                                |
| Permissions | Accessibility permission (required)     |
| Build       | Xcode 15.0 or later (source build only) |

## 2. Install with Homebrew (recommended)

```bash
brew tap finfra/tap
brew install finfra/tap/fwarrange-cli
brew services start fwarrange-cli     # start + auto-start at login
```

The app is installed at `/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app`; once running, its icon appears in the menu bar.

| Task      | Command                                                             |
| --------- | ------------------------------------------------------------------- |
| Stop      | `brew services stop fwarrange-cli`                                  |
| Restart   | `brew services restart fwarrange-cli`                               |
| Update    | `brew upgrade fwarrange-cli`                                        |
| Uninstall | `brew services stop fwarrange-cli` → `brew uninstall fwarrange-cli` |

Layouts and settings in `~/Documents/finfra/fWarrangeData/` are kept after uninstalling. Delete that folder manually to remove them.

## 3. Build from Source

```bash
git clone https://github.com/Finfra/fWarrange_public.git
cd fWarrange_public/cli
xcodebuild -scheme fWarrangeCli -configuration Release build
```

Output: `~/Library/Developer/Xcode/DerivedData/fWarrangeCli-*/Build/Products/Release/fWarrangeCli.app`

## 4. Accessibility Permission

**fWarrangeCli** needs the Accessibility permission to change window positions and sizes.

1. **System Settings** › **Privacy & Security** › **Accessibility**
2. Turn on **fWarrangeCli** (if missing, add `/opt/homebrew/opt/fwarrange-cli/fWarrangeCli.app` with `+`)
3. Check: `curl -s http://localhost:3016/api/v2/status/accessibility`

| Symptom                                    | Fix                                                               |
| ------------------------------------------ | ----------------------------------------------------------------- |
| Enabled in the list but windows don't move | Toggle it off and on, or remove it with `-` and add it again      |
| Permission lost after a source build       | Each build has a different signature — register it again          |
| Shortcuts respond but windows don't move   | The permission is off — repeat steps 1–2 and restart fWarrangeCli |

## 5. Check the REST API

The REST server is **enabled by default** (port 3016).

```bash
curl -s http://localhost:3016/api/v2/status
```

`"status" : "ok"` means it is working. Turning the server off, the port, and external access are set in `_config.yml` — see [Menu Bar Usage › Configuration File](04_MenuBar_Usage.md#configuration-file-_configyml).

## 6. (Optional) GUI Wrapper fWarrange

To use a layout list, minimap, and settings window, also install the App Store app **fWarrange**. fWarrange works through this fWarrangeCli — see the [fWarrange product page](https://finfra.kr/product/fWarrange/en/index.html).

## Next Steps

* [Quick Start](03_QuickStart.md)
* [Menu Bar Usage](04_MenuBar_Usage.md)
