#!/bin/bash
# POST /api/v2/settings/factory-reset (모든 설정 기본값 초기화)
# 파괴적 동작이므로 FORCE=1 환경변수로만 실행됨
BASE="http://localhost:3016/api/v2"
if [ "${FORCE:-0}" != "1" ]; then
  echo "SKIP: 파괴적 테스트. 실행하려면 FORCE=1 ./18.v2-factory-reset.sh" >&2
  exit 0
fi
curl -s --connect-timeout 3 -X POST "$BASE/settings/factory-reset" \
  -H "X-Confirm: true" | jq .
