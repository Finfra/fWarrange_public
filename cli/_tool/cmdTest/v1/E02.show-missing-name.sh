#!/bin/bash
# show 커맨드에 이름 누락 → 에러
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI show
echo "exit code: $?"
