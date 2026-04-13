#!/bin/bash
# PATCH /api/v2/settings/api (REST 서버 설정 업데이트 - 안전한 기본값으로 복원)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X PATCH "$BASE/settings/api" \
  -H "Content-Type: application/json" \
  -d '{"restServerEnabled": true, "restServerPort": 3016, "allowExternalAccess": false}' | jq .
