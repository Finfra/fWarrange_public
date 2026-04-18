#!/bin/bash
# v2 settings api patch (안전한 기본값으로 복원)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 settings api patch '{"restServerEnabled":true,"restServerPort":3016,"allowExternalAccess":false}' | jq .
