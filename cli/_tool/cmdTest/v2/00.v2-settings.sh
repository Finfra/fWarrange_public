#!/bin/bash
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
# v2 settings (전체 GET)
$CLI v2 settings | jq .
