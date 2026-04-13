#!/bin/bash
# 확인 헤더 없이 종료 → 400
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X POST "$BASE/cli/quit" | jq .
