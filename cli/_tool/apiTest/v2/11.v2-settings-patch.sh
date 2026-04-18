#!/bin/bash
# PATCH /api/v2/settings (전체 설정 중 임의 필드 부분 업데이트 - 안전한 기본값)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X PATCH "$BASE/settings" \
  -H "Content-Type: application/json" \
  -d '{"theme": "system"}' | jq .
