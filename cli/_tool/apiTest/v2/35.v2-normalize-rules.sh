#!/bin/bash
# Title normalize rules — GET /normalize-rules (v2)
# Issue72_3 (Phase 3): 타이틀 정규화 룰셋 조회
BASE="http://localhost:3016/api/v2"
echo "--- GET /normalize-rules (v2) ---"
curl -s --connect-timeout 3 "$BASE/normalize-rules" | jq .
