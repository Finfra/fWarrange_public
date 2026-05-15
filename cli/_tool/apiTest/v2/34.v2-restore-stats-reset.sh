#!/bin/bash
# Reset restore matching statistics — DELETE /restore-stats (v2)
# Issue72_1 (Phase 1): 베이스라인 재시작용 통계 초기화
BASE="http://localhost:3016/api/v2"
echo "--- DELETE /restore-stats (v2) ---"
curl -s --connect-timeout 3 -X DELETE "$BASE/restore-stats" | jq .
echo ""
echo "--- 초기화 확인: GET /restore-stats ---"
curl -s --connect-timeout 3 "$BASE/restore-stats" | jq .
