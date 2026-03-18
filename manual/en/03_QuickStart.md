# Quick Start

The core workflow of fWarrange is a simple **Save -> Move -> Restore** 3-step process.

## 3-Step Workflow

### Step 1: Save Current Layout (Capture)

Arrange your apps as desired, then save the state.

**GUI:**
- Menu bar icon > Click "Capture" button

**CLI:**
```bash
cd lib/wArrange_core/
swift saveWindowsInfo.swift --name=myWorkspace
```

**API:**
```bash
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"myWorkspace"}'
```

### Step 2: Windows Move Around

Your windows change positions during work, or you switch to a different layout.

### Step 3: Restore Saved Layout

Bring all windows back to their saved positions.

**GUI:**
- Menu bar icon > Select layout from list > Click "Restore"

**CLI:**
```bash
cd lib/wArrange_core/
swift setWindows.swift --name=myWorkspace
```

**API:**
```bash
curl -X POST http://localhost:3016/api/v1/layouts/myWorkspace/restore
```

## Use Cases

### Scenario 1: Switching Work Contexts
```bash
# Save coding layout
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"coding"}'

# Save meeting layout
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"meeting"}'

# Switch as needed
curl -X POST http://localhost:3016/api/v1/layouts/coding/restore
curl -X POST http://localhost:3016/api/v1/layouts/meeting/restore
```

### Scenario 2: Capture Specific Apps Only
```bash
curl -X POST http://localhost:3016/api/v1/capture \
  -H "Content-Type: application/json" \
  -d '{"name":"webDev", "filterApps":["Safari","iTerm2"]}'
```

### Scenario 3: Layout Management
```bash
# List all layouts
curl -s http://localhost:3016/api/v1/layouts | python3 -m json.tool

# Get layout details
curl -s http://localhost:3016/api/v1/layouts/myWorkspace | python3 -m json.tool

# Rename layout
curl -X PUT http://localhost:3016/api/v1/layouts/myWorkspace \
  -H "Content-Type: application/json" \
  -d '{"newName":"dailySetup"}'

# Delete layout
curl -X DELETE http://localhost:3016/api/v1/layouts/dailySetup
```

## Next Steps

- [GUI Usage](04_GUI_Usage.md) - Detailed settings guide
- [CLI Usage](05_CLI_Usage.md) - Script options reference
- [REST API Usage](06_API_Usage.md) - Full endpoint reference
