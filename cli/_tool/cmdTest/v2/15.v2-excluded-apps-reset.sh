#!/bin/bash
# v2 excluded-apps reset (기본값 초기화)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 excluded-apps reset | jq .
