# CLI Usage

fWarrange's core functionality is implemented as standalone Swift scripts that can be used directly from the terminal without the GUI.

## Working Directory

All CLI scripts are run from the `lib/wArrange_core/` directory:

```bash
cd lib/wArrange_core/
```

## Saving Layouts (saveWindowsInfo.swift)

Captures all visible window positions and sizes and saves them as a YAML file.

### Basic Usage

```bash
# Save with default filename (data/windowInfo.yml)
swift saveWindowsInfo.swift

# Verbose output mode
swift saveWindowsInfo.swift -v

# Specify filename
swift saveWindowsInfo.swift --name=myLayout

# Save specific apps only
swift saveWindowsInfo.swift --app=Safari,iTerm2
```

### Parameters

| Option | Description | Default |
|--------|-------------|---------|
| `-v` | Verbose output of collected window info | Disabled |
| `--name=<name>` | Output filename (no extension needed) | windowInfo |
| `--app=<app1,app2>` | Capture only specified apps | All apps |

### Output Example (-v mode)

```
[saveWindowsInfo] Safari - "Google" pos=(100, 200) size=(1200x800)
[saveWindowsInfo] iTerm2 - "~ - zsh" pos=(0, 25) size=(800x600)
[saveWindowsInfo] Xcode - "fWarrange" pos=(-1707, 99) size=(1707x1280)
Saved 3 windows to: data/myLayout.yml
```

## Restoring Layouts (setWindows.swift)

Reads a saved YAML file and restores each window to its original position.

### Basic Usage

```bash
# Restore from default file (data/windowInfo.yml)
swift setWindows.swift

# Verbose output mode
swift setWindows.swift -v

# Restore specific layout
swift setWindows.swift --name=myLayout
```

### Parameters

| Option | Description | Default |
|--------|-------------|---------|
| `-v` | Verbose matching scores and retry details | Disabled |
| `--name=<name>` | Layout filename to restore | windowInfo |

### Window Matching Score System

| Score | Condition | Description |
|-------|-----------|-------------|
| 100 | Window ID match | System window ID is identical |
| 90 | Exact title match | Window title matches perfectly |
| 80 | Regex match | Pattern-based title matching |
| 70 | Title contains | Keyword found in window title |
| 60-30 | Geometric similarity | Size, ratio, area comparison |

## Diagnostic Scripts

### list_apps.swift - Accessibility API Window List

```bash
swift list_apps.swift
```

Verifies that Accessibility permissions are properly configured.

### list_all_apps.swift - Running Apps List

```bash
swift list_all_apps.swift
```

Lists all running apps using NSWorkspace.

### list_cg.swift - CoreGraphics Window List

```bash
swift list_cg.swift
```

Lists windows as seen by CoreGraphics. Comparing with `list_apps.swift` helps diagnose permission issues.

## Data File Format

Layout files use YAML format:

```yaml
- app: "Safari"
  window: "Google"
  layer: 0
  id: 14205
  pos:
    x: 100.0
    y: 200.0
  size:
    width: 1200.0
    height: 800.0
```

File location: `lib/wArrange_core/data/<name>.yml`

## Automation Integration

### cron Example
```bash
# Restore dev layout at 9 AM daily
0 9 * * * cd /path/to/lib/wArrange_core && swift setWindows.swift --name=dev
```

### Alfred/Raycast Integration
Specify the script path to bind to a hotkey.

## Next Steps

- [REST API Usage](06_API_Usage.md)
- [Skill Usage](07_Skill_Usage.md)
