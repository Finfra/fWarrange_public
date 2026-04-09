#!/bin/bash
# fWarrangeCli windows 테스트
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI windows | jq .
