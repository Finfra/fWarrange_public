#!/bin/bash
# quit에 --confirm 없이 실행 → 에러
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI quit
echo "exit code: $?"
