#!/bin/bash
# 존재하지 않는 커맨드 → 에러 + help
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI foobar
echo "exit code: $?"
