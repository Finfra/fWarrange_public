#!/bin/bash
# 테스트: 캡처 → 삭제
BASE="http://localhost:3016/api/v2"
TEST_NAME="_apitest_delete"

# 준비: 테스트용 레이아웃 캡처
curl -s --connect-timeout 3 -X POST "$BASE/capture" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TEST_NAME\"}" > /dev/null

# 실행: 삭제
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts/$TEST_NAME" | jq .
