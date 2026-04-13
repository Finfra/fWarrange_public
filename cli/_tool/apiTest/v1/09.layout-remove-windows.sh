#!/bin/bash
# 테스트: 캡처 → 첫 번째 윈도우 ID 추출 → 제거 → 정리
BASE="http://localhost:3016/api/v1"
TEST_NAME="_apitest_rmwin"

# 준비: 테스트용 레이아웃 캡처
curl -s --connect-timeout 3 -X POST "$BASE/capture" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TEST_NAME\"}" > /dev/null

# 첫 번째 윈도우 ID 추출
WIN_ID=$(curl -s --connect-timeout 3 "$BASE/layouts/$TEST_NAME" | jq '.data.windows[0].id')

# 실행: 윈도우 제거
curl -s --connect-timeout 3 -X POST "$BASE/layouts/$TEST_NAME/windows/remove" \
  -H "Content-Type: application/json" \
  -d "{\"windowIds\": [$WIN_ID]}" | jq .

# 정리
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts/$TEST_NAME" > /dev/null
