#!/bin/bash
# 에러 테스트: X-Confirm 헤더 없이 factory-reset → 400
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X POST "$BASE/settings/factory-reset" | jq .
