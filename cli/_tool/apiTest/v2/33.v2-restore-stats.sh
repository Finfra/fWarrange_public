#!/bin/bash
# Restore matching statistics — GET /restore-stats (v2)
# Issue72_1 (Phase 1): 창 복구 매칭 누적 통계 조회
BASE="http://localhost:3016/api/v2"
echo "--- GET /restore-stats (v2) ---"
curl -s --connect-timeout 3 "$BASE/restore-stats" | jq .
