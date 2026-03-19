# fWarrange REST API Documentation

## Overview

fWarrange provides a REST API for saving and restoring macOS window positions and sizes.

| Server | Tech Stack | Default Port |
|--------|-----------|--------------|
| macOS Native App | Swift / Network.framework (NWListener) | 3016 |

All responses follow the `{"status": "ok", "data": ...}` wrapper format. The API is **disabled** by default and must be enabled in the app settings.

> OpenAPI 3.0 Spec: [openapi.yaml](./openapi.yaml)

---

## Endpoints

### 1. Health Check

```
GET /
```

**Response**:
```json
{
  "status": "ok",
  "app": "fWarrange",
  "version": "1.08",
  "port": 3016
}
```

---

### 2. List Layouts

```
GET /api/v1/layouts
```

**Response**:
```json
{
  "status": "ok",
  "data": [
    {
      "name": "myLayout",
      "windowCount": 12,
      "fileDate": "2026-03-17T10:30:00Z"
    }
  ]
}
```

---

### 3. Get Layout Detail

```
GET /api/v1/layouts/{name}
```

#### Path Parameters

| Field  | Type   | Required | Description                                  |
|--------|--------|----------|----------------------------------------------|
| `name` | string | Yes      | Layout name (YAML filename without extension) |

**Response (200)**: Full window information (name, windowCount, fileDate, windows array)

**Errors**:

| Status | Cause            | Example                                                       |
|--------|------------------|---------------------------------------------------------------|
| 404    | Layout not found | `{"status": "error", "error": "Layout 'unknown' not found"}` |

---

### 4. Rename Layout

```
PUT /api/v1/layouts/{name}
Content-Type: application/json
```

#### Request Parameters

| Field     | Type   | Required | Description      |
|-----------|--------|----------|------------------|
| `newName` | string | Yes      | New layout name  |

#### Request Example

```json
{
  "newName": "workSetup-v2"
}
```

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "oldName": "workSetup",
    "newName": "workSetup-v2"
  }
}
```

**Errors**:

| Status | Cause            |
|--------|------------------|
| 400    | Invalid request  |
| 404    | Layout not found |

---

### 5. Delete Layout

```
DELETE /api/v1/layouts/{name}
```

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "deleted": "myLayout"
  }
}
```

---

### 6. Delete All Layouts

```
DELETE /api/v1/layouts
```

Requires `X-Confirm-Delete-All: true` header as a safety measure.

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "deletedCount": 5
  }
}
```

**Errors**:

| Status | Cause                        |
|--------|------------------------------|
| 400    | Missing confirmation header  |

---

### 7. Capture and Save Current Windows

```
POST /api/v1/capture
Content-Type: application/json
```

#### Request Parameters

| Field        | Type     | Required | Default              | Description        |
|--------------|----------|----------|----------------------|--------------------|
| `name`       | string   | No       | Auto-generated date  | Layout name        |
| `filterApps` | string[] | No       | All apps             | App name filter    |

#### Request Example

```json
{
  "name": "myLayout",
  "filterApps": ["Safari", "iTerm2"]
}
```

Sending an empty body `{}` applies default values.

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "name": "myLayout",
    "windowCount": 5,
    "windows": [...]
  }
}
```

---

### 8. Restore Layout

```
POST /api/v1/layouts/{name}/restore
Content-Type: application/json
```

Processed asynchronously using a score-based window matching algorithm. **Accessibility permission required**.

#### Request Parameters

| Field            | Type    | Required | Default | Description                      |
|------------------|---------|----------|---------|----------------------------------|
| `maxRetries`     | integer | No       | 5       | Maximum retry attempts           |
| `retryInterval`  | number  | No       | 0.5     | Retry interval in seconds        |
| `minimumScore`   | integer | No       | 30      | Minimum matching score (0-100)   |
| `enableParallel` | boolean | No       | true    | Enable parallel restore per app  |

#### Request Example

```json
{
  "maxRetries": 3,
  "retryInterval": 1.0,
  "minimumScore": 50,
  "enableParallel": true
}
```

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "total": 10,
    "succeeded": 8,
    "failed": 2,
    "results": [
      {
        "app": "Safari",
        "window": "Start Page",
        "matchType": "ID",
        "score": 100,
        "success": true
      }
    ]
  }
}
```

**Errors**:

| Status | Cause                            |
|--------|----------------------------------|
| 403    | Accessibility permission denied  |
| 404    | Layout not found                 |

---

### 9. Remove Specific Windows from Layout

```
POST /api/v1/layouts/{name}/windows/remove
Content-Type: application/json
```

#### Request Parameters

| Field       | Type      | Required | Description               |
|-------------|-----------|----------|---------------------------|
| `windowIds` | integer[] | Yes      | Window IDs to remove      |

#### Request Example

```json
{
  "windowIds": [14205, 5032]
}
```

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "layout": "myLayout",
    "removedCount": 2,
    "remainingCount": 10
  }
}
```

---

### 10. Get Current Windows

```
GET /api/v1/windows/current
```

Returns all currently visible windows without saving to file.

#### Query Parameters

| Field        | Type   | Required | Description                                      |
|--------------|--------|----------|--------------------------------------------------|
| `filterApps` | string | No       | Comma-separated app name filter (e.g. `Safari,iTerm2`) |

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "windowCount": 15,
    "windows": [...]
  }
}
```

---

### 11. List Running Apps

```
GET /api/v1/windows/apps
```

**Response**:
```json
{
  "status": "ok",
  "data": {
    "apps": ["Safari", "iTerm2", "Xcode", "Finder", "Slack"]
  }
}
```

---

### 12. Accessibility Permission Status

```
GET /api/v1/status/accessibility
```

**Response**:
```json
{
  "status": "ok",
  "data": {
    "granted": true
  }
}
```

---

### 13. Get Current Locale

```
GET /api/v1/locale
```

**Response**:
```json
{
  "status": "ok",
  "data": {
    "current": "ko",
    "supported": ["system", "ko", "en", "ja", "ar", "zh-Hans", "zh-Hant", "fr", "de", "hi", "es"]
  }
}
```

---

### 14. Change App Language

```
PUT /api/v1/locale
Content-Type: application/json
```

Requires app restart to take effect. Use `"system"` to follow macOS system language.

#### Request Parameters

| Field      | Type   | Required | Description                              |
|------------|--------|----------|------------------------------------------|
| `language` | string | Yes      | Language code (e.g. `ko`, `en`, `system`) |

**Response (200)**:
```json
{
  "status": "ok",
  "data": {
    "language": "en",
    "restartRequired": true
  }
}
```

---

## Usage Examples

### cURL

```bash
# Health check
curl http://localhost:3016/

# List layouts
curl http://localhost:3016/api/v1/layouts

# Get layout detail
curl http://localhost:3016/api/v1/layouts/myLayout

# Capture and save current windows
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "myLayout"}'

# Capture specific apps only
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "safariOnly", "filterApps": ["Safari", "iTerm2"]}'

# Restore layout
curl -X POST http://localhost:3016/api/v1/layouts/myLayout/restore \
  -H "Content-Type: application/json" \
  -d '{}'

# Rename layout
curl -X PUT http://localhost:3016/api/v1/layouts/myLayout \
  -H "Content-Type: application/json" \
  -d '{"newName": "workSetup"}'

# Delete layout
curl -X DELETE http://localhost:3016/api/v1/layouts/myLayout

# Delete all (confirmation header required)
curl -X DELETE http://localhost:3016/api/v1/layouts \
  -H "X-Confirm-Delete-All: true"

# Get current windows (without saving)
curl http://localhost:3016/api/v1/windows/current

# Filter by specific apps
curl "http://localhost:3016/api/v1/windows/current?filterApps=Safari,iTerm2"

# List running apps
curl http://localhost:3016/api/v1/windows/apps

# Accessibility permission status
curl http://localhost:3016/api/v1/status/accessibility

# Get current locale
curl http://localhost:3016/api/v1/locale

# Change language
curl -X PUT http://localhost:3016/api/v1/locale \
  -H "Content-Type: application/json" \
  -d '{"language": "en"}'
```

### Python

```python
import requests

BASE = "http://localhost:3016"

# List layouts
layouts = requests.get(f"{BASE}/api/v1/layouts").json()
print(layouts["data"])

# Capture current windows
response = requests.post(
    f"{BASE}/api/v1/capture",
    json={"name": "myLayout"}
)
print(response.json())

# Restore layout
response = requests.post(
    f"{BASE}/api/v1/layouts/myLayout/restore",
    json={}
)
result = response.json()
print(f"Restored: {result['data']['succeeded']}/{result['data']['total']}")
```

---

## Security

| Item            | Description                                                             |
|-----------------|-------------------------------------------------------------------------|
| Default binding | `127.0.0.1` (localhost only)                                            |
| Default state   | **Disabled** (must be enabled in app settings)                          |
| External access | Must be explicitly enabled; binds to `0.0.0.0` with CIDR whitelist     |
| CIDR default    | `192.168.0.0/16` (multiple ranges supported, comma-separated)          |
| Localhost       | Always allowed regardless of CIDR settings                              |
| Rejected IPs    | `403 Forbidden` response                                               |

> **Warning**: This API must NOT be exposed to the public internet.

---

## Error Response Format

All errors follow the same format:

```json
{
  "status": "error",
  "error": "Error message"
}
```

| Status | Common Causes                                          |
|--------|--------------------------------------------------------|
| 400    | Invalid JSON, missing required parameters, missing header |
| 403    | Accessibility permission denied, CIDR blocked          |
| 404    | Layout not found, invalid path                         |
| 500    | Internal server error                                  |

---

## Testing

```bash
# Automated tests (14 items)
bash api/test-api.sh [port]

# Example: custom port
bash api/test-api.sh 3017
```

Test items:
1. Health Check (GET `/`)
2. Accessibility status check
3. Running apps list
4. Current windows list
5. Current windows (filtered by app)
6. Capture and save windows
7. List layouts
8. Get layout detail
9. Rename layout
10. Get renamed layout detail
11. Restore layout
12. Delete layout
13. 404 response handling
14. Delete all without header (400 handling)
