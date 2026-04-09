#!/bin/bash
# fWarrangeCli apps 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI apps | jq .
