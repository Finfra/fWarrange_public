#!/bin/bash
# Usage: ./run.sh [run-only]
#   run-only: 빌드 없이 실행만

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"
APP_PATH="/Applications/_nowage_app/fWarrangeCli.app"
MODE="${1:-build-run}"

echo "=== Step 1: 기존 프로세스 종료 ==="
pkill -9 -f MacOS/fWarrangeCli 2>/dev/null || true
sleep 1

# Xcode 디버거에 잡힌 경우
if pgrep -f MacOS/fWarrangeCli > /dev/null 2>&1; then
    echo "⚠️  잔존 프로세스 발견 — Xcode stop 시도"
    osascript -e 'tell application "Xcode" to stop (every workspace document)' 2>/dev/null || true
    sleep 2
fi

if [ "$MODE" != "run-only" ]; then
    echo "=== Step 2: Debug 빌드 ==="
    cd "$CLI_DIR"
    xcodebuild -scheme fWarrangeCli -configuration Debug build -quiet

    echo "=== Step 3: 배포 ==="
    BUILD_DIR=$(xcodebuild -scheme fWarrangeCli -showBuildSettings 2>/dev/null | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)
    mkdir -p /Applications/_nowage_app
    rm -rf "$APP_PATH"
    cp -R "$BUILD_DIR/fWarrangeCli.app" "$APP_PATH"
    xattr -cr "$APP_PATH"
fi

echo "=== Step 4: 실행 ==="
open "$APP_PATH"

echo "=== Step 5: 동작 확인 ==="
sleep 3
HEALTH=$(curl -s --connect-timeout 3 http://localhost:3016/ 2>/dev/null)
if [ -n "$HEALTH" ]; then
    echo "✅ REST API 정상"
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
else
    echo "❌ REST API 응답 없음 (포트 3016)"
fi
