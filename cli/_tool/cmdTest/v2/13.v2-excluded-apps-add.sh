#!/bin/bash
# v2 excluded-apps add (POST)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 excluded-apps add "Xcode" | jq .
