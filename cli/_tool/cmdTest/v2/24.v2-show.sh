#!/bin/bash
# fWarrangeCli show 테스트 (v2 경로)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
NAME=${1:-testCmdV2}
$CLI show "$NAME" | jq .
