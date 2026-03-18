---
name: fwarrange
description: "Save and restore macOS window layouts via fWarrange REST API"
argument-hint: "[capture|restore|list|status] [layout-name]"
---

# fWarrange Window Layout Management

Save and restore macOS window positions and sizes via the fWarrange REST API.

## Input

$ARGUMENTS

If no arguments are provided, ask the user what action they want to perform:
- **capture**: Save the current window layout
- **restore [name]**: Restore a saved layout
- **list**: List all saved layouts
- **status**: Check accessibility permission status

## Prerequisites

The fWarrange REST API server (`http://localhost:3016`) must be running:

| Server           | How to Run                                        |
| ---------------- | ------------------------------------------------- |
| macOS Native App | Launch fWarrange.app (REST API enabled by default) |

## Execution Steps

1. **Check Server**: Verify the fWarrange server is running.
   ```bash
   curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" http://localhost:3016/
   ```
   If the server is not responding, inform the user with the launch command:
   > "fWarrange REST API server is not running. Launch the app with:"
   > ```bash
   > open -a "fWarrange"
   > ```
   > "Let me know when ready."

   Do NOT attempt to start the server automatically. Wait for user confirmation before proceeding.

2. **Execute Action** based on $ARGUMENTS:

   **a. `capture` or `capture --name=<name>`** — Save current window layout
   ```bash
   # Default name (auto-generated timestamp)
   curl -s -X POST http://localhost:3016/api/v1/capture \
     -H 'Content-Type: application/json' | python3 -m json.tool

   # With custom name
   curl -s -X POST http://localhost:3016/api/v1/capture \
     -H 'Content-Type: application/json' \
     -d '{"name":"<LAYOUT_NAME>"}' | python3 -m json.tool
   ```

   **b. `restore <name>`** — Restore a saved layout
   ```bash
   curl -s -X POST http://localhost:3016/api/v1/layouts/<NAME>/restore | python3 -m json.tool
   ```

   **c. `list`** — List all saved layouts
   ```bash
   curl -s http://localhost:3016/api/v1/layouts | python3 -m json.tool
   ```

   **d. `status`** — Check accessibility permission
   ```bash
   curl -s http://localhost:3016/api/v1/status/accessibility | python3 -m json.tool
   ```

   **e. `windows`** — Show current windows
   ```bash
   curl -s http://localhost:3016/api/v1/windows/current | python3 -m json.tool
   ```

   **f. `apps`** — Show running applications
   ```bash
   curl -s http://localhost:3016/api/v1/windows/apps | python3 -m json.tool
   ```

3. **Report**: Inform the user of the result (layout name, window count, success/failure details).

## API Reference

| Method | Endpoint                                  | Description                |
| ------ | ----------------------------------------- | -------------------------- |
| GET    | `/`                                       | Health check               |
| GET    | `/api/v1/layouts`                         | List all layouts           |
| GET    | `/api/v1/layouts/{name}`                  | Get layout details         |
| POST   | `/api/v1/capture`                         | Capture current layout     |
| POST   | `/api/v1/layouts/{name}/restore`          | Restore a layout           |
| PUT    | `/api/v1/layouts/{name}`                  | Rename a layout            |
| DELETE | `/api/v1/layouts/{name}`                  | Delete a layout            |
| DELETE | `/api/v1/layouts`                         | Delete all layouts (*)     |
| POST   | `/api/v1/layouts/{name}/windows/remove`   | Remove specific windows    |
| GET    | `/api/v1/windows/current`                 | List current windows       |
| GET    | `/api/v1/windows/apps`                    | List running apps          |
| GET    | `/api/v1/status/accessibility`            | Check accessibility status |
| GET    | `/api/v1/locale`                          | Get locale setting         |
| PUT    | `/api/v1/locale`                          | Change locale setting      |

(*) Requires `X-Confirm-Delete-All: true` header.

**Response format:**
- Success: `{"status": "ok", "data": {...}}`
- Error: `{"status": "error", "error": "..."}`

## Usage

### Capture current layout
```bash
curl -s -X POST http://localhost:3016/api/v1/capture \
  -H 'Content-Type: application/json' \
  -d '{"name":"my-workspace"}' | python3 -m json.tool
```

### Restore a layout
```bash
curl -s -X POST http://localhost:3016/api/v1/layouts/my-workspace/restore | python3 -m json.tool
```

### List saved layouts
```bash
curl -s http://localhost:3016/api/v1/layouts | python3 -m json.tool
```

### Get layout details
```bash
curl -s http://localhost:3016/api/v1/layouts/my-workspace | python3 -m json.tool
```

### Delete a layout
```bash
curl -s -X DELETE http://localhost:3016/api/v1/layouts/my-workspace | python3 -m json.tool
```

## Options

- `--name=<layout-name>`: Specify layout name for capture/restore
- `--server=<url>`: Change server address (default: `http://localhost:3016`)

## Examples

```
/fwarrange:fwarrange capture
/fwarrange:fwarrange capture --name=coding-setup
/fwarrange:fwarrange restore my-workspace
/fwarrange:fwarrange list
/fwarrange:fwarrange status
/fwarrange:fwarrange windows
/fwarrange:fwarrange apps
```
