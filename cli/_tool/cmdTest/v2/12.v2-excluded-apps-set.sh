#!/bin/bash
# v2 excluded-apps set (전체 교체 PUT)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 excluded-apps set "Activity Monitor" "System Settings" "Finder" | jq .
