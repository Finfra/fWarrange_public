#!/bin/bash
# fWarrangeCli show 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
NAME=${1:-testCmd}
$CLI show "$NAME" | jq .
