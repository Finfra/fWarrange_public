#!/bin/bash
# fWarrangeCli capture 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
NAME=${1:-testCmd}
$CLI capture "$NAME" | jq .
