#!/bin/bash
# fWarrangeCli delete 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
NAME=${1:-testCmdRenamed}
$CLI delete "$NAME" | jq .
