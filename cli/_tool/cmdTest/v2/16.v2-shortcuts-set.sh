#!/bin/bash
# v2 shortcuts set (현재 saveShortcut 값을 그대로 왕복 검증)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
CURRENT=$($CLI v2 shortcuts | jq -r '.data.saveShortcut // empty')
$CLI v2 shortcuts set "{\"saveShortcut\":\"${CURRENT}\"}" | jq .
