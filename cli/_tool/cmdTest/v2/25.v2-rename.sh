#!/bin/bash
# fWarrangeCli rename 테스트 (v2 경로)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
OLD=${1:-testCmdV2}
NEW=${2:-testCmdV2Renamed}
$CLI rename "$OLD" "$NEW" | jq .
