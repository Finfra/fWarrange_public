---
title: fWarrangeCli
description: fWarrange companion helper daemon — REST API server for window capture/restore
date: 2026-04-07
---

A companion helper daemon for [fWarrange](https://github.com/Finfra/fWarrange_public). Runs as a menu bar agent app and provides a REST API for window capture and restore operations.

fWarrange (App Store version) delegates all Accessibility API operations to this daemon, enabling Sandbox compliance.

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

Auto-start at login is managed within the app (via macOS Login Items).
Homebrew handles installation only — no `brew services` needed.

```bash
# Manual launch
open /Applications/_nowage_app/fWarrangeCli.app
```

# REST API

* **Default port**: `3016`
* **API version**: `v2` (current), `v1` (legacy, maintained)
* **Service root**: `http://localhost:3016/api/v2`
* **OpenAPI spec**: [`api/openapi_v2.yaml`](../api/openapi_v2.yaml) · [`api/openapi_v1.yaml`](../api/openapi_v1.yaml) (legacy)

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
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "my-layout"}'

# Restore layout
curl -X POST http://localhost:3016/api/v1/layouts/my-layout/restore

# Check status
curl http://localhost:3016/api/v1/cli/status
```

# Configuration

Settings are stored in UserDefaults:

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

Shared with fWarrange GUI app.

# Accessibility Permission

fWarrangeCli requires Accessibility permission to control window positions:

**System Settings > Privacy & Security > Accessibility > Add fWarrangeCli**

# License

Copyright (c) Finfra. All rights reserved.
