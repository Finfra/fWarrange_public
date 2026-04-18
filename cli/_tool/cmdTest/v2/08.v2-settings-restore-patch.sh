#!/bin/bash
# v2 settings restore patch (안전한 기본값)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 settings restore patch '{"maxRetries":5}' | jq .
