---
title: fWarrange Installation Guide
description: fWarrange 설치 및 초기 설정 가이드 (English)
date: 2026-03-26
---
# Installation & Permission Setup

## 1. System Requirements

| Item  | Minimum                      |
| ----- | ---------------------------- |
| macOS | 15.0 (Sequoia) or later      |
| Swift | 5.10 or later                |
| Xcode | 16.0 or later (for building) |
| Disk  | Approximately 50MB           |

## 2. Installation Methods

### 2.1. Pre-built App (Recommended)

1. Copy `fWarrange.app` to `/Applications/` or your preferred folder
2. On first launch, click "Open" if macOS Gatekeeper warning appears

### 2.2. Build from Source

```bash
# Clone repository
git clone https://github.com/nowage/fWarrange.git
cd fWarrange

# Build with Xcode
cd fWarrange
xcodebuild -scheme fWarrange -configuration Debug build
```

Build output is generated at the DerivedData path:
```
~/Library/Developer/Xcode/DerivedData/fWarrange-*/Build/Products/Debug/fWarrange.app
```

## 2.3. CLI-only Usage (Without GUI)

You can use the core scripts without the GUI app:

```bash
cd lib/wArrange_core/
swift saveWindowsInfo.swift    # Capture
swift setWindows.swift         # Restore
```

## 3. Accessibility Permission Setup

Accessibility permission is **required** to control window positions and sizes.

### 3.1. Granting Permission

1. Open **System Settings**
2. Navigate to **Privacy & Security** > **Accessibility**
3. Click the lock icon at the bottom-left to unlock
4. Click `+` to add:
   - **For GUI app**: `fWarrange.app`
   - **For CLI scripts**: `Terminal.app` or `iTerm2.app`

### 3.2. Verifying Permission

```bash
# Verify via CLI
cd lib/wArrange_core/
swift list_apps.swift
```

If output appears normally, permissions are correctly configured.

You can also verify via REST API:
```bash
curl -s http://localhost:3016/api/v1/status/accessibility | python3 -m json.tool
```

## 3.3. Troubleshooting Permissions

| Symptom                          | Solution                                                          |
| -------------------------------- | ----------------------------------------------------------------- |
| App is listed but doesn't work   | Uncheck and recheck, or remove and re-add the app                 |
| Permission dialog doesn't appear | Run `tccutil reset Accessibility` in terminal, then reconfigure   |
| Permission lost after rebuild    | Each build has a different binary signature; re-register required |

## 4. Activating REST API Server

The REST API server is **disabled** by default.

1. Launch fWarrange app
2. Click menu bar icon > **Settings**
3. Go to **API** tab
4. Toggle **Enable Server** ON
5. Confirm port (default: 3016)

## Next Steps

* [Quick Start](03_QuickStart.md)
* [GUI Usage](04_GUI_Usage.md)
