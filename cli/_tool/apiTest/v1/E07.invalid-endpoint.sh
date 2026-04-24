#!/bin/bash
# 존재하지 않는 엔드포인트 → error
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 "$BASE/nonexistent" | jq .
