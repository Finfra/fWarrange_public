#!/bin/bash
# PATCH /api/v2/settings/restore (복구 탭 설정 업데이트 - 안전한 기본값)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X PATCH "$BASE/settings/restore" \
  -H "Content-Type: application/json" \
  -d '{"enableParallelRestore": true}' | jq .
