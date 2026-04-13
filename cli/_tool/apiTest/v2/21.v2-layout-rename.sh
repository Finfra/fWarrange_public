#!/bin/bash
# 테스트: 캡처 → 리네임 → 원복
BASE="http://localhost:3016/api/v2"
TEST_NAME="_apitest_rename_src"
TEST_NEW="_apitest_rename_dst"

# 준비: 테스트용 레이아웃 캡처
curl -s --connect-timeout 3 -X POST "$BASE/capture" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TEST_NAME\"}" > /dev/null

# 실행: 리네임
curl -s --connect-timeout 3 -X PUT "$BASE/layouts/$TEST_NAME" \
  -H "Content-Type: application/json" \
  -d "{\"newName\": \"$TEST_NEW\"}" | jq .

# 정리: 리네임된 레이아웃 삭제
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts/$TEST_NEW" > /dev/null
