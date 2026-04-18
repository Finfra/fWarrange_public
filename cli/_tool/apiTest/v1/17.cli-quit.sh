#!/bin/bash
# POST /api/v1/cli/quit — 데몬 종료 (위험: all 실행 시 이후 테스트 실패)
# 실행하려면: FORCE=1 ./17.cli-quit.sh
BASE="http://localhost:3016/api/v1"
if [ "${FORCE:-0}" != "1" ]; then
  echo "SKIP: 데몬 종료 테스트. 실행하려면 FORCE=1 ./17.cli-quit.sh" >&2
  exit 0
fi
curl -s --connect-timeout 3 -X POST "$BASE/cli/quit" \
  -H "X-Confirm: true" | jq .
