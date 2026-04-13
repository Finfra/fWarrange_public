#!/bin/bash
# 기본 레이아웃 이름 조회 및 설정 테스트
BASE="http://localhost:3016/api/v1"

echo "=== GET /settings/default-layout ==="
curl -s --connect-timeout 3 "$BASE/settings/default-layout" | jq .

echo ""
echo "=== PUT /settings/default-layout ==="
curl -s --connect-timeout 3 -X PUT "$BASE/settings/default-layout" \
  -H "Content-Type: application/json" \
  -d '{"name":"myDefault"}' | jq .

echo ""
echo "=== GET /settings/default-layout (변경 확인) ==="
curl -s --connect-timeout 3 "$BASE/settings/default-layout" | jq .

echo ""
echo "=== PUT /settings/default-layout (원복) ==="
curl -s --connect-timeout 3 -X PUT "$BASE/settings/default-layout" \
  -H "Content-Type: application/json" \
  -d '{"name":"default"}' | jq .
