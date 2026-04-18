#!/bin/bash
# Usage: ./kill.sh
#   fWarrangeCli 프로세스를 종료함 (다른 Xcode 워크스페이스 영향 금지)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=fwc-config.sh
source "$SCRIPT_DIR/fwc-config.sh"

pkill -9 -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
sleep 1

# Xcode 디버거에 잡힌 경우 — 특정 워크스페이스만 stop
if pgrep -f "MacOS/$PROJECT_NAME" > /dev/null 2>&1; then
    echo "⚠️  잔존 프로세스 발견 — $XCODEPROJ_NAME stop 시도"
    osascript 2>/dev/null <<APPLESCRIPT || true
tell application "Xcode"
    try
        stop (workspace document "$XCODEPROJ_NAME")
    end try
end tell
APPLESCRIPT
    sleep 2
fi

echo "✅ $PROJECT_NAME 프로세스 종료 완료"
