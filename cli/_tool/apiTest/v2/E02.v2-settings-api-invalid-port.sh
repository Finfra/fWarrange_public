#!/bin/bash
# 에러 테스트: 잘못된 포트 값(65536, 범위 초과) → 400
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X PATCH "$BASE/settings/api" \
  -H "Content-Type: application/json" \
  -d '{"restServerPort": 65536}' | jq .
