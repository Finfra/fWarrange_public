---
title: fWarrangeCli API Usage
description: fWarrangeCli REST API usage (English)
date: 2026.10.08
---
# REST API Usage

fWarrangeCli provides a REST API (v2) through its built-in HTTP server. You can remotely invoke the core features from curl, Apple Shortcuts, automation scripts, and more. The GUI wrapper **fWarrange** also works through this API.

> This chapter covers the commonly used endpoints only. The authoritative list of endpoints and request/response schemas is [`api/openapi_v2.yaml`](../../api/openapi_v2.yaml). v1 (`/api/v1/*`) is retired and returns `410 Gone`.

## Server Information

| Item                  | Value                                |
| --------------------- | ------------------------------------ |
| Default Address       | `http://localhost:3016`              |
| Framework             | Apple Network.framework (NWListener) |
| External Dependencies | None (pure Swift implementation)     |
| Content-Type          | `application/json; charset=utf-8`    |

## Checking the Server

The REST API server is built into fWarrangeCli and is **enabled by default**.

1. Launch fWarrangeCli (running if its icon is in the menu bar)
2. Check the response of `curl -s http://localhost:3016/api/v2/status`
3. The menu bar **Daemon ▸ Status** also shows it — if you use fWarrange, its settings window **API** tab shows it too
4. Turning the server off or allowing external access is set with `restServerEnabled` · `allowExternalAccess` · `allowedCIDR` in `~/Documents/finfra/fWarrangeData/_config.yml`

## Response Format

All responses are JSON:

```json
// Success
{"status": "ok", "data": {...}}

// Error
{"status": "error", "error": "error message"}
```

## Endpoint Reference (main)

### Status

#### GET / - Health Check

```bash
curl -s http://localhost:3016/ | python3 -m json.tool
```

Response:
```json
{
    "app": "fWarrangeCli",
    "isApiPaused": false,
    "isRunning": true,
    "port": 3016,
    "status": "ok",
    "uptime": "35:04:00",
    "uptimeSeconds": 126240,
    "version": "1.1.1"
}
```

### Layout Management

#### GET /api/v2/layouts - List Layouts

```bash
curl -s http://localhost:3016/api/v2/layouts | python3 -m json.tool
```

#### GET /api/v2/layouts/{name} - Get Layout Detail

```bash
curl -s http://localhost:3016/api/v2/layouts/myLayout | python3 -m json.tool
```

#### POST /api/v2/capture - Capture and Save Windows

```bash
# Default (auto-generated name)
curl -s -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" | python3 -m json.tool

# With name
curl -s -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"myLayout"}' | python3 -m json.tool

# Specific apps only
curl -s -X POST http://localhost:3016/api/v2/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"webDev", "filterApps":["Safari","iTerm2"]}' | python3 -m json.tool
```

Request body:

| Field      | Type     | Required | Description                                       |
| ---------- | -------- | -------- | ------------------------------------------------- |
| name       | string   | No       | Layout name (auto-generated from date if omitted) |
| filterApps | string[] | No       | Apps to capture (all if omitted)                  |

## POST /api/v2/layouts/{name}/restore - Restore Layout

```bash
# Default settings
curl -s -X POST http://localhost:3016/api/v2/layouts/myLayout/restore | python3 -m json.tool

# Custom settings
curl -s -X POST http://localhost:3016/api/v2/layouts/myLayout/restore \
  -H "Content-Type: application/json" \
  -d '{"maxRetries":3, "retryInterval":1.0, "minimumScore":50, "enableParallel":true}' | python3 -m json.tool
```

Request body (optional):

| Field          | Type   | Default | Description                    |
| -------------- | ------ | ------- | ------------------------------ |
| maxRetries     | int    | 5       | Maximum retry attempts         |
| retryInterval  | double | 0.5     | Retry interval in seconds      |
| minimumScore   | int    | 30      | Minimum matching score (0-100) |
| enableParallel | bool   | true    | Per-app parallel restore       |

Response:
```json
{
    "status": "ok",
    "data": {
        "total": 12,
        "succeeded": 11,
        "failed": 1,
        "results": [
            {"app": "Safari", "window": "Google", "matchType": "ID", "score": 100, "success": true}
        ]
    }
}
```

## PUT /api/v2/layouts/{name} - Rename Layout

```bash
curl -s -X PUT http://localhost:3016/api/v2/layouts/myLayout \
  -H "Content-Type: application/json" \
  -d '{"newName":"dailySetup"}' | python3 -m json.tool
```

### DELETE /api/v2/layouts/{name} - Delete Layout

```bash
curl -s -X DELETE http://localhost:3016/api/v2/layouts/myLayout | python3 -m json.tool
```

#### DELETE /api/v2/layouts - Delete All Layouts

Requires confirmation header for safety:

```bash
curl -s -X DELETE http://localhost:3016/api/v2/layouts \
  -H "X-Confirm-Delete-All: true" | python3 -m json.tool
```

#### POST /api/v2/layouts/{name}/windows/remove - Remove Specific Windows

```bash
curl -s -X POST http://localhost:3016/api/v2/layouts/myLayout/windows/remove \
  -H "Content-Type: application/json" \
  -d '{"windowIds":[14205, 5032]}' | python3 -m json.tool
```

### Window Queries

#### GET /api/v2/windows/current - Current Windows (Without Saving)

```bash
# All windows
curl -s http://localhost:3016/api/v2/windows/current | python3 -m json.tool

# Specific apps only
curl -s "http://localhost:3016/api/v2/windows/current?filterApps=Safari,iTerm2" | python3 -m json.tool
```

## GET /api/v2/windows/apps - Running Apps

```bash
curl -s http://localhost:3016/api/v2/windows/apps | python3 -m json.tool
```

### System Status

#### GET /api/v2/status/accessibility - Accessibility Permission Status

```bash
curl -s http://localhost:3016/api/v2/status/accessibility | python3 -m json.tool
```

## Security

### Default Security Policy

| Item              | Setting                               |
| ----------------- | ------------------------------------- |
| Default Binding   | `127.0.0.1` (localhost only)          |
| Default State     | Disabled (manual activation required) |
| Internet Exposure | Prohibited (local/LAN only)           |

### When Allowing External Access

1. Settings > API tab > Enable **External Access**
2. Configure CIDR whitelist (default: `192.168.0.0/16`)
3. Server binds to `0.0.0.0`
4. Non-whitelisted IPs receive **403 Forbidden**
5. `127.0.0.1` and `::1` are always allowed

### CIDR Configuration Examples

```
192.168.0.0/16              # Typical home/office LAN
10.0.0.0/8                  # VPN range
192.168.1.0/24,10.0.0.0/8   # Multiple ranges (comma-separated)
```

## Apple Shortcuts Integration

Automate fWarrangeCli via the macOS Shortcuts app:

1. Open Shortcuts app
2. Create new shortcut
3. Add "Get Contents of URL" action
4. URL: `http://localhost:3016/api/v2/layouts/myLayout/restore`
5. Method: POST
6. Run via Siri, keyboard shortcut, or menu bar

## API Specification

Full OpenAPI 3.0 spec is available at:
* [`api/openapi_v2.yaml`](../../api/openapi_v2.yaml) (v2, current)
* Human-readable notes: [cli/_doc_arch/RestAPI_v2.md](../../cli/_doc_arch/RestAPI_v2.md)

## Next Steps

* [Menu Bar Usage](04_MenuBar_Usage.md) — server settings in `_config.yml`
* [Skill Usage](06_Skill_Usage.md)
* [MCP Server Usage](07_MCP_Usage.md)
