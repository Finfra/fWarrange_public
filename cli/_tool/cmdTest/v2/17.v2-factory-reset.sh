#!/bin/bash
# v2 factory-reset (파괴적, FORCE=1 게이트)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
if [ "${FORCE:-0}" != "1" ]; then
  echo "SKIP: 파괴적 테스트. 실행하려면 FORCE=1 ./17.v2-factory-reset.sh" >&2
  exit 0
fi
$CLI v2 factory-reset --confirm | jq .
