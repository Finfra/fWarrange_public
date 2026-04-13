#!/bin/bash
# fWarrangeCli rename 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
OLD=${1:-testCmd}
NEW=${2:-testCmdRenamed}
$CLI rename "$OLD" "$NEW" | jq .
