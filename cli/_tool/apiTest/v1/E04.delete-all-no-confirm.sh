#!/bin/bash
# 확인 헤더 없이 전체 삭제 → 400
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts" | jq .
