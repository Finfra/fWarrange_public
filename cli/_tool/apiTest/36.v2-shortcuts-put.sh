#!/bin/bash
# PUT /api/v2/settings/shortcuts (단축키 업데이트 - v1과 동일 시맨틱)
# 테스트 전략: 현재 saveShortcut 값을 그대로 다시 써서 상태 변경 없이 왕복 검증
BASE="http://localhost:3016/api/v2"
CURRENT=$(curl -s --connect-timeout 3 "$BASE/settings/shortcuts" | jq -r '.data.saveShortcut // empty')
curl -s --connect-timeout 3 -X PUT "$BASE/settings/shortcuts" \
  -H "Content-Type: application/json" \
  -d "{\"saveShortcut\": \"${CURRENT}\"}" | jq .
