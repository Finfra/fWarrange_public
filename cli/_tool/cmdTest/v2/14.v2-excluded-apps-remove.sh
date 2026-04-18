#!/bin/bash
# v2 excluded-apps remove (DELETE)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 excluded-apps remove "Xcode" | jq .
