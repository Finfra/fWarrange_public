#!/bin/bash
# fWarrangeCli remove-windows 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
NAME=${1:-testCmd}
WINDOW_ID=${2:-1234}
$CLI remove-windows "$NAME" "$WINDOW_ID" | jq .
