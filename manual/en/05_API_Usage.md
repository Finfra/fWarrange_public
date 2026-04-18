---
title: fWarrange API Usage
description: fWarrange REST API 사용 방법 (English)
date: 2026-03-26
---
# REST API Usage

fWarrange provides a REST API through its built-in HTTP server. You can remotely invoke all core features from curl, Apple Shortcuts, automation scripts, and more.

## Server Information

| Item                  | Value                                |
| --------------------- | ------------------------------------ |
| Default Address       | `http://localhost:3016`              |
| Framework             | Apple Network.framework (NWListener) |
| External Dependencies | None (pure Swift implementation)     |
| Content-Type          | `application/json; charset=utf-8`    |

## Activating the Server

1. Launch fWarrange app
2. Menu bar icon > Settings > **API** tab
3. Toggle **Enable Server** ON
4. Confirm port (default: 3016)

## Response Format

All responses are JSON:

```json
// Success
{"status": "ok", "data": {...}}

// Error
{"status": "error", "error": "error message"}
```

## Endpoint Reference (14 endpoints)

### Status

#### GET / - Health Check

```bash
curl -s http://localhost:3016/ | python3 -m json.tool
```

Response:
```json
{
    "status": "ok",
    "app": "fWarrange",
    "version": "1.08",
    "port": 3016
}
```

### Layout Management

#### GET /api/v1/layouts - List Layouts

```bash
curl -s http://localhost:3016/api/v1/layouts | python3 -m json.tool
```

#### GET /api/v1/layouts/{name} - Get Layout Detail

```bash
curl -s http://localhost:3016/api/v1/layouts/myLayout | python3 -m json.tool
```

#### POST /api/v1/capture - Capture and Save Windows

```bash
# Default (auto-generated name)
curl -s -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" | python3 -m json.tool

# With name
curl -s -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"myLayout"}' | python3 -m json.tool

# Specific apps only
curl -s -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"webDev", "filterApps":["Safari","iTerm2"]}' | python3 -m json.tool
```

Request body:

| Field      | Type     | Required | Description                                       |
| ---------- | -------- | -------- | ------------------------------------------------- |
| name       | string   | No       | Layout name (auto-generated from date if omitted) |
| filterApps | string[] | No       | Apps to capture (all if omitted)                  |

## POST /api/v1/layouts/{name}/restore - Restore Layout

```bash
# Default settings
curl -s -X POST http://localhost:3016/api/v1/layouts/myLayout/restore | python3 -m json.tool

# Custom settings
curl -s -X POST http://localhost:3016/api/v1/layouts/myLayout/restore \
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

## PUT /api/v1/layouts/{name} - Rename Layout

```bash
curl -s -X PUT http://localhost:3016/api/v1/layouts/myLayout \
  -H "Content-Type: application/json" \
  -d '{"newName":"dailySetup"}' | python3 -m json.tool
```

### DELETE /api/v1/layouts/{name} - Delete Layout

```bash
curl -s -X DELETE http://localhost:3016/api/v1/layouts/myLayout | python3 -m json.tool
```

#### DELETE /api/v1/layouts - Delete All Layouts

Requires confirmation header for safety:

```bash
curl -s -X DELETE http://localhost:3016/api/v1/layouts \
  -H "X-Confirm-Delete-All: true" | python3 -m json.tool
```

#### POST /api/v1/layouts/{name}/windows/remove - Remove Specific Windows

```bash
curl -s -X POST http://localhost:3016/api/v1/layouts/myLayout/windows/remove \
  -H "Content-Type: application/json" \
  -d '{"windowIds":[14205, 5032]}' | python3 -m json.tool
```

### Window Queries

#### GET /api/v1/windows/current - Current Windows (Without Saving)

```bash
# All windows
curl -s http://localhost:3016/api/v1/windows/current | python3 -m json.tool

# Specific apps only
curl -s "http://localhost:3016/api/v1/windows/current?filterApps=Safari,iTerm2" | python3 -m json.tool
```

## GET /api/v1/windows/apps - Running Apps

```bash
curl -s http://localhost:3016/api/v1/windows/apps | python3 -m json.tool
```

### System Status

#### GET /api/v1/status/accessibility - Accessibility Permission Status

```bash
curl -s http://localhost:3016/api/v1/status/accessibility | python3 -m json.tool
```

#### GET /api/v1/locale - Current Locale

```bash
curl -s http://localhost:3016/api/v1/locale | python3 -m json.tool
```

Response:
```json
{
    "status": "ok",
    "data": {
        "current": "ko",
        "supported": ["system", "ko", "en", "ja", "ar", "zh-Hans", "zh-Hant", "fr", "de", "hi", "es"]
    }
}
```

#### PUT /api/v1/locale - Change Language

```bash
curl -s -X PUT http://localhost:3016/api/v1/locale \
  -H "Content-Type: application/json" \
  -d '{"language":"en"}' | python3 -m json.tool
```

> App restart is required after language change.

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

Automate fWarrange via the macOS Shortcuts app:

1. Open Shortcuts app
2. Create new shortcut
3. Add "Get Contents of URL" action
4. URL: `http://localhost:3016/api/v1/layouts/myLayout/restore`
5. Method: POST
6. Run via Siri, keyboard shortcut, or menu bar

## API Specification

Full OpenAPI 3.0 spec is available at:
* `api/openapi_v1.yaml`

## Next Steps

* [Skill Usage](06_Skill_Usage.md)
* [MCP Server Usage](07_MCP_Usage.md)
