#!/bin/bash
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
# v2 excluded-apps (GET)
$CLI v2 excluded-apps | jq .
