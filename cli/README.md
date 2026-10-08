---
title: fWarrangeCli
description: fWarrange companion helper daemon — REST API server for window capture/restore
date: 2026.10.08
---

fWarrangeCli is the engine that saves and restores macOS window layouts. It runs as a menu bar agent app and offers global shortcuts, a command line, and a REST API.

> **fWarrange is a GUI wrapper for fWarrangeCli.** The App Store app fWarrange (Sandbox) adds a layout list, minimap, and settings window, and delegates every capture and restore to this daemon over the REST API. fWarrangeCli works on its own without fWarrange.

User manual: [manual/](../manual/README.md) · fWarrange (GUI): [product page](https://finfra.kr/product/fWarrange/en/index.html)

# Architecture

```
fWarrange (Sandbox, App Store)          fWarrangeCli (Non-Sandbox, Helper)
├── SwiftUI GUI                         ├── RESTServer (port 3016)
├── RESTClient ──── HTTP ─────────────► ├── WindowManager
│   (localhost:3016)                    │   ├── CGWindowCaptureService
│                                       │   └── AXWindowRestoreService
└── SettingsSheet                       ├── LayoutManager (YAML I/O)
                                        └── HotKeyService (Global Shortcuts)
```

# Requirements

* macOS 14.0 or later
* Xcode 15.0+ (build only)
* Accessibility permission granted

# Install

## Homebrew (recommended)

> * The **source code** is Apache-2.0. Build it yourself and use it without any limit.
> * **Official Builds** (the Homebrew package below) are free for personal use, education, non-profits, open-source projects, and any other organization on up to **250 concurrent copies**. Beyond that, or for resale / bundling / hosting, you need a commercial license ([COMMERCIAL.md](../COMMERCIAL.md)). Installing means you accept [DISTRIBUTION-TERMS.md](../DISTRIBUTION-TERMS.md).

```bash
brew tap finfra/tap
brew install finfra/tap/fwarrange-cli
```

## Build from Source

```bash
cd ../cli
xcodebuild -scheme fWarrangeCli -configuration Release build
```

# Service Management

With Homebrew, run fWarrangeCli as a `brew services` service (launchd) — it starts now and at every login, and launchd restarts it if it crashes.

```bash
brew services start fwarrange-cli      # start + auto-start at login
brew services restart fwarrange-cli    # restart (e.g. after editing _config.yml)
brew services stop fwarrange-cli       # stop
```

The menu bar item **🚀 Launch at Login** (`launchAtLogin` in `_config.yml`) controls the login item for builds launched without `brew services`. See [Installation](../manual/en/02_Install.md).

# REST API

* **Default port**: `3016`
* **API version**: `v2` only — `v1` is retired and every `/api/v1/*` request returns `410 Gone`
* **Service root**: `http://localhost:3016/api/v2`
* **OpenAPI spec**: [`api/openapi_v2.yaml`](../api/openapi_v2.yaml)

## Endpoints

All endpoints are relative to service root `/api/v2`. Full spec: [`api/openapi_v2.yaml`](../api/openapi_v2.yaml)

### Status

| Method | Path      | Description                                         |
| :----- | :-------- | :-------------------------------------------------- |
| GET    | `/health` | Health check (also available at absolute root `GET /`) |

### Layouts

| Method | Path                             | Description                |
| :----- | :------------------------------- | :------------------------- |
| GET    | `/layouts`                       | List layouts               |
| GET    | `/layouts/{name}`                | Get layout detail          |
| PUT    | `/layouts/{name}`                | Rename layout              |
| DELETE | `/layouts/{name}`                | Delete layout              |
| DELETE | `/layouts`                       | Delete all (X-Confirm-Delete-All header) |
| POST   | `/layouts/{name}/windows/remove` | Remove specific windows    |

### Capture & Restore

| Method | Path                        | Description              |
| :----- | :-------------------------- | :----------------------- |
| POST   | `/capture`                  | Capture and save windows |
| POST   | `/layouts/{name}/restore`   | Restore layout           |

### Windows

| Method | Path               | Description                           |
| :----- | :----------------- | :------------------------------------ |
| GET    | `/windows/current` | Current windows (filterApps query)    |
| GET    | `/windows/apps`    | Running apps                          |

### System

| Method | Path                      | Description              |
| :----- | :------------------------ | :----------------------- |
| GET    | `/status/accessibility`   | Accessibility permission |
| GET    | `/locale`                 | Current locale           |
| PUT    | `/locale`                 | Change app language      |

### UI

| Method | Path        | Description                                 |
| :----- | :---------- | :------------------------------------------ |
| PUT    | `/ui/state` | Control UI state (hide windows, select apps) |

### CLI Management

| Method | Path           | Description                             |
| :----- | :------------- | :-------------------------------------- |
| GET    | `/cli/status`  | Daemon status (uptime, version, port)   |
| GET    | `/cli/version` | Version info                            |
| POST   | `/cli/quit`    | Quit daemon (X-Confirm header required) |

## Quick Test

```bash
# Health check
curl http://localhost:3016/

# Capture current windows
curl -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "my-layout"}'

# Restore layout
curl -X POST http://localhost:3016/api/v2/layouts/my-layout/restore

# Check status
curl http://localhost:3016/api/v2/cli/status
```

# Configuration

Settings are stored in `~/Documents/finfra/fWarrangeData/_config.yml` (menu **Configuration ▸ Open Config File**). The fWarrange settings window edits the same file. Main keys:

| Key                   | Default | Description              |
| :-------------------- | :------ | :----------------------- |
| restServerPort        | 3016    | REST server port         |
| maxRetries            | 5       | Window match retry count |
| retryInterval         | 0.5     | Retry interval (seconds) |
| minimumMatchScore     | 30      | Minimum match score      |
| enableParallelRestore | true    | Parallel restore mode    |
| dataStorageMode       | host    | `host` or `share`        |

# Data Directory

Layout files (YAML) are stored in:

```
~/Documents/finfra/fWarrangeData/{hostname}/*.yml
```

fWarrange (GUI) reads the same folder through the REST API.

# Accessibility Permission

fWarrangeCli requires Accessibility permission to control window positions:

**System Settings > Privacy & Security > Accessibility > Add fWarrangeCli**

# License

fWarrangeCli source code is licensed under the [Apache License 2.0](../LICENSE) (see also [NOTICE](../NOTICE)).

* **Official builds** (Homebrew `finfra/tap`, GitHub Releases) are additionally covered by [DISTRIBUTION-TERMS.md](../DISTRIBUTION-TERMS.md) — free for personal use, education, non-profits, open-source projects, and other organizations up to 250 concurrent copies. Builds you compile yourself are not affected
* Names and icon: [TRADEMARK.md](../TRADEMARK.md) · Commercial licensing: [COMMERCIAL.md](../COMMERCIAL.md)

Copyright (c) 2026 Finfra Co., Ltd. (https://finfra.kr)
