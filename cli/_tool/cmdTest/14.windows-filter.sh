#!/bin/bash
# fWarrangeCli windows --filter 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
FILTER=${1:-Safari}
$CLI windows --filter "$FILTER" | jq .
