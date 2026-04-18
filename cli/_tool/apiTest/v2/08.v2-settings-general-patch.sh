#!/bin/bash
# PATCH /api/v2/settings/general (일반 탭 설정 업데이트 - 안전한 기본값)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X PATCH "$BASE/settings/general" \
  -H "Content-Type: application/json" \
  -d '{"theme": "system"}' | jq .
