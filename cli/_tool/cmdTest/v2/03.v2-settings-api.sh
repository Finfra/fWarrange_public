#!/bin/bash
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
# v2 settings api (GET)
$CLI v2 settings api | jq .
